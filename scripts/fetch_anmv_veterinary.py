#!/usr/bin/env python3
"""
Télécharge la base officielle ANMV (Anses) V2 et produit
``FICHIER MED VETERINAIRES2026.csv`` pour offiboxdata.

Source open data (MAJ officielle chaque mardi) :
  https://pro.anses.fr/RCP/amm-vet-fr-v2.xls
  https://www.data.gouv.fr/datasets/base-de-donnees-publique-des-medicaments-veterinaires-autorises-en-france-1

Format Offibox (séparateur ``;``, UTF-8) :
  ligne 1 : Date d'extraction
  lignes suivantes : libellé 🐾 (VETO) ; GTIN13 ; URL RCP ircp.anmv.anses.fr

Usage :
  python scripts/fetch_anmv_veterinary.py
  python scripts/fetch_anmv_veterinary.py --push   # OFFIBOXDATA_GITHUB_TOKEN ou GITHUB_TOKEN
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path
from urllib.parse import quote
from urllib.request import Request, urlopen

try:
    import xlrd
except ImportError:
    print("Dépendance manquante : pip install xlrd", file=sys.stderr)
    raise

ANMV_XLS_URL = "https://pro.anses.fr/RCP/amm-vet-fr-v2.xls"
OUT_NAME = "FICHIER MED VETERINAIRES2026.csv"
GITHUB_OWNER = "AlexandrePerrault"
GITHUB_REPO = "offiboxdata"
GITHUB_BRANCH = "main"
USER_AGENT = "Offibox-ANMV-Fetch/1.0"
TIMEOUT = 180

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUT = ROOT / OUT_NAME


def fetch_bytes(url: str) -> bytes:
    req = Request(url, headers={"User-Agent": USER_AGENT})
    with urlopen(req, timeout=TIMEOUT) as resp:
        return resp.read()


def _sheet_dict(book: xlrd.book.Book, name: str) -> list[dict[str, object]]:
    sh = book.sheet_by_name(name)
    if sh.nrows < 2:
        return []
    headers = [str(sh.cell_value(0, c)).strip() for c in range(sh.ncols)]
    rows: list[dict[str, object]] = []
    for r in range(1, sh.nrows):
        row: dict[str, object] = {}
        empty = True
        for c, key in enumerate(headers):
            if not key:
                continue
            val = sh.cell_value(r, c)
            if val not in ("", None):
                empty = False
            row[key] = val
        if not empty:
            rows.append(row)
    return rows


def _digits_gtin(raw: object) -> str:
    if raw is None or raw == "":
        return ""
    if isinstance(raw, float):
        if raw != raw:  # NaN
            return ""
        raw = int(raw) if raw == int(raw) else raw
    s = re.sub(r"\D", "", str(raw).strip())
    return s


def _str_cell(raw: object) -> str:
    if raw is None:
        return ""
    if isinstance(raw, float):
        if raw != raw:
            return ""
        if raw == int(raw):
            return str(int(raw))
    return str(raw).strip()


def _export_timestamp(book: xlrd.book.Book) -> datetime:
    sh = book.sheet_by_name("Date export")
    if sh.nrows < 1 or sh.ncols < 1:
        return datetime.now()
    cell = sh.cell_value(0, 0)
    if isinstance(cell, float):
        try:
            return datetime(*xlrd.xldate_as_tuple(cell, book.datemode))
        except Exception:
            pass
    parsed = datetime.fromisoformat(_str_cell(cell).replace("Z", "+00:00"))
    return parsed


def build_offibox_csv(xls_bytes: bytes) -> tuple[str, int, datetime]:
    book = xlrd.open_workbook(file_contents=xls_bytes)
    export_dt = _export_timestamp(book)
    med_rows = _sheet_dict(book, "Med")
    gtin_rows = _sheet_dict(book, "Codes GTIN Modeles vente")

    id_key = "N° d'identification"
    name_key = "Nom du médicament"
    rcp_key = "Lien RCP"
    gtin_key = "Code GTIN"
    model_key = "Modèle destiné à la vante"

    med_by_id: dict[str, tuple[str, str]] = {}
    for row in med_rows:
        mid = _str_cell(row.get(id_key))
        if not mid:
            continue
        nom = _str_cell(row.get(name_key))
        url = _str_cell(row.get(rcp_key))
        if nom:
            med_by_id[mid] = (nom, url)

    lines: list[str] = []
    seen: set[tuple[str, str, str]] = set()
    for row in gtin_rows:
        gtin = _digits_gtin(row.get(gtin_key))
        if not gtin:
            continue
        mid = _str_cell(row.get(id_key))
        med = med_by_id.get(mid)
        if med is None:
            continue
        nom, url = med
        modele = _str_cell(row.get(model_key))
        label = f"🐾 (VETO) {nom}"
        if modele:
            label += f" – {modele}"
        key = (label, gtin, url)
        if key in seen:
            continue
        seen.add(key)
        lines.append(
            ";".join(
                f'"{part.replace(chr(34), chr(34)*2)}"'
                for part in (label, gtin, url)
            )
        )

    lines.sort(key=lambda ln: ln.lower())
    stamp = export_dt.strftime("%d/%m/%Y %H:%M:%S")
    header = f'"Date d\'extraction : {stamp}";"";""'
    body = "\n".join([header, *lines])
    return body, len(lines), export_dt


def push_github(content: str, token: str) -> None:
    path_encoded = quote(OUT_NAME, safe="")
    api_url = (
        f"https://api.github.com/repos/{GITHUB_OWNER}/{GITHUB_REPO}"
        f"/contents/{path_encoded}"
    )
    headers = {
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": USER_AGENT,
        "Authorization": (
            f"Bearer {token}" if token.startswith("github_pat_") else f"token {token}"
        ),
    }
    sha = None
    req_get = Request(api_url + f"?ref={GITHUB_BRANCH}", headers=headers)
    with urlopen(req_get, timeout=60) as resp:
        if resp.status == 200:
            meta = json.loads(resp.read().decode("utf-8"))
            sha = meta.get("sha")

    now = datetime.now()
    payload = {
        "message": f"🔄 MAJ EXTRACTION_ANMV – {now.strftime('%d/%m/%Y %H:%M:%S')}",
        "content": base64.b64encode(content.encode("utf-8")).decode("ascii"),
        "branch": GITHUB_BRANCH,
    }
    if sha:
        payload["sha"] = sha

    req_put = Request(
        api_url,
        data=json.dumps(payload).encode("utf-8"),
        headers={**headers, "Content-Type": "application/json"},
        method="PUT",
    )
    with urlopen(req_put, timeout=120) as resp:
        if resp.status not in (200, 201):
            raise RuntimeError(f"GitHub API HTTP {resp.status}: {resp.read()[:500]!r}")


def main() -> int:
    parser = argparse.ArgumentParser(description="ANMV → FICHIER MED VETERINAIRES2026.csv")
    parser.add_argument("-o", "--output", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--push", action="store_true", help="Pousse vers offiboxdata (token requis)")
    args = parser.parse_args()

    print(f"Téléchargement {ANMV_XLS_URL}…", file=sys.stderr)
    xls_bytes = fetch_bytes(ANMV_XLS_URL)
    print(f"  {len(xls_bytes):,} octets", file=sys.stderr)

    csv_text, row_count, export_dt = build_offibox_csv(xls_bytes)
    args.output.write_text(csv_text, encoding="utf-8", newline="\n")
    print(
        f"Écrit {args.output} — {row_count} présentations GTIN, "
        f"export Anses {export_dt.isoformat(sep=' ', timespec='seconds')}",
        file=sys.stderr,
    )

    if args.push:
        token = (
            os.environ.get("OFFIBOXDATA_GITHUB_TOKEN")
            or os.environ.get("GITHUB_TOKEN")
            or ""
        ).strip()
        if not token:
            print("Pas de token GitHub — --push ignoré", file=sys.stderr)
            return 1
        push_github(csv_text, token)
        print(f"Poussé vers {GITHUB_REPO}/{OUT_NAME}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
