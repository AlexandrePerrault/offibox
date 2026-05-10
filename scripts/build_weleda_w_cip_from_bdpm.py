#!/usr/bin/env python3
"""
Construit assets/data/weleda_w_cip13.csv : formules Weleda (W…) → CIP13 (+ CIS) depuis
les fichiers officiels BDPM (tabulations), comme dans lib/data/bdpm_labels_loader.dart.

Usage :
  python scripts/build_weleda_w_cip_from_bdpm.py
  python scripts/build_weleda_w_cip_from_bdpm.py --cis path/CIS_bdpm.txt --cip path/CIS_CIP_bdpm.txt --weleda path/weleda_formules.csv --out path/weleda_w_cip13.csv

Sans arguments : télécharge CIS_bdpm.txt, CIS_CIP_bdpm.txt et weleda_formules.csv (GitHub Offibox).
Sortie CSV séparateur « ; » : formule_w;cip13;cis
  - colonne 1 : code W (ex. W306)
  - colonne 2 : CIP13 chiffres uniquement
  - colonne 3 : CIS (pour liens BDPM dans l’app ; optionnel si présent dans les fichiers)
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
import urllib.request
from io import StringIO
from pathlib import Path

CIS_BDPM_URL = (
    "https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_bdpm.txt"
)
CIS_CIP_URL = (
    "https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_CIP_bdpm.txt"
)
WELEDA_FORMULES_URL = (
    "https://raw.githubusercontent.com/AlexandrePerrault/offibox/master/weleda_formules.csv"
)

# Aligné sur bdpm_labels_loader.dart
COL_CIS_CODE = 0
COL_CIS_DENOM = 1
COL_CIS_FORME = 2
COL_CIPCIP_CIS = 0
COL_CIPCIP_LIB = 2
COL_CIPCIP_CIP13 = 6

W_CODE_RE = re.compile(r"\b(W\d+)\b", re.I)


def fetch_text(url: str) -> str:
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "Offibox-weleda-cip-script/1.0"},
    )
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read().decode("utf-8", errors="replace")


def parse_cis_bdpm(text: str) -> dict[str, tuple[str, str]]:
    """cis -> (denomination, forme_pharmaceutique)"""
    out: dict[str, tuple[str, str]] = {}
    for line in text.splitlines():
        t = line.strip()
        if not t:
            continue
        cols = t.split("\t")
        if len(cols) <= COL_CIS_FORME:
            continue
        cis = re.sub(r"\D", "", cols[COL_CIS_CODE]).strip()
        if not cis:
            continue
        denom = cols[COL_CIS_DENOM].strip()
        forme = cols[COL_CIS_FORME].strip()
        out[cis] = (denom, forme)
    return out


def iter_cip_rows(text: str):
    for line in text.splitlines():
        t = line.strip()
        if not t:
            continue
        cols = t.split("\t")
        if len(cols) <= COL_CIPCIP_CIP13:
            continue
        cis = re.sub(r"\D", "", cols[COL_CIPCIP_CIS]).strip()
        lib = cols[COL_CIPCIP_LIB].strip()
        cip13 = re.sub(r"\D", "", cols[COL_CIPCIP_CIP13]).strip()
        if len(cip13) != 13 or not cip13.startswith("34009"):
            continue
        yield cis, lib, cip13


def score_match(
    wu: str,
    denom: str,
    libelle: str,
    weleda_forme: str,
    weleda_contenance: str,
) -> int:
    wu_up = wu.upper()
    lib_l = libelle.lower()
    blob_l = f"{weleda_forme} {weleda_contenance}".lower()

    score = 0
    if re.search(rf"\b{re.escape(wu_up)}\b", denom.upper()):
        score += 5
    elif re.search(rf"\b{re.escape(wu_up)}\b", libelle.upper()):
        score += 5

    wants_granules = "granule" in blob_l
    wants_gouttes = "goutte" in blob_l or "solution buvable" in blob_l
    wants_poudre = "poudre" in blob_l

    if wants_granules and ("granule" in lib_l or "granules" in lib_l):
        score += 4
    if wants_gouttes and (
        "goutte" in lib_l or "solution" in lib_l or "flacon" in lib_l
    ):
        score += 4
    if wants_poudre and "poudre" in lib_l:
        score += 4

    return score


def pick_cip_for_weleda_row(
    formule: str,
    forme: str,
    contenance: str,
    cis_by_code: dict[str, tuple[str, str]],
    cip_rows: list[tuple[str, str, str]],
) -> tuple[str, str] | None:
    m = W_CODE_RE.search(formule.strip())
    if not m:
        return None
    wu = m.group(1).upper()

    candidates: list[tuple[int, str, str]] = []
    for cis, lib, cip13 in cip_rows:
        info = cis_by_code.get(cis)
        denom = info[0] if info else ""
        score = score_match(wu, denom, lib, forme, contenance)
        if score < 5:
            continue
        candidates.append((score, cip13, cis))

    if not candidates:
        return None
    best_score = max(c[0] for c in candidates)
    if len(candidates) > 1 and best_score < 8:
        # Ambiguïté : même seuil que WeledaCipResolver._pickPresentation côté Dart.
        return None
    candidates.sort(key=lambda x: (-x[0], x[1]))
    _, cip13, cis = candidates[0]
    return (cip13, cis)


def load_weleda_formules(path_or_url: str, raw: str | None = None) -> list[tuple[str, str, str, str]]:
    """(formule, composition, forme, contenance)"""
    text = raw if raw is not None else fetch_text(path_or_url)
    rows: list[tuple[str, str, str, str]] = []
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        parts = [p.replace('"', "").strip() for p in line.split(";")]
        if len(parts) < 4:
            continue
        if parts[0].lower().startswith("formule"):
            continue  # en-tête
        formule = parts[0]
        if not W_CODE_RE.search(formule):
            continue
        rows.append((formule, parts[1], parts[2], parts[3]))
    return rows


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--cis", help="Chemin CIS_bdpm.txt")
    ap.add_argument("--cip", help="Chemin CIS_CIP_bdpm.txt")
    ap.add_argument("--weleda", help="Chemin ou URL weleda_formules.csv")
    ap.add_argument(
        "--out",
        default=str(
            Path(__file__).resolve().parent.parent / "assets" / "data" / "weleda_w_cip13.csv"
        ),
        help="CSV de sortie",
    )
    args = ap.parse_args()

    if args.cis and args.cip:
        cis_text = Path(args.cis).read_text(encoding="utf-8", errors="replace")
        cip_text = Path(args.cip).read_text(encoding="utf-8", errors="replace")
    else:
        print("Téléchargement BDPM…", file=sys.stderr)
        cis_text = fetch_text(CIS_BDPM_URL)
        cip_text = fetch_text(CIS_CIP_URL)

    if args.weleda:
        p = Path(args.weleda)
        if p.is_file():
            weleda_raw = p.read_text(encoding="utf-8", errors="replace")
            weleda_rows = load_weleda_formules("", raw=weleda_raw)
        else:
            weleda_raw = fetch_text(args.weleda)
            weleda_rows = load_weleda_formules("", raw=weleda_raw)
    else:
        print("Téléchargement weleda_formules.csv…", file=sys.stderr)
        weleda_raw = fetch_text(WELEDA_FORMULES_URL)
        weleda_rows = load_weleda_formules("", raw=weleda_raw)

    cis_by_code = parse_cis_bdpm(cis_text)
    cip_rows = list(iter_cip_rows(cip_text))

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    lines_out: list[tuple[str, str, str]] = []
    seen_w: set[str] = set()

    for formule, _comp, forme, contenance in weleda_rows:
        m = W_CODE_RE.search(formule)
        if not m:
            continue
        wkey = m.group(1).upper()
        if wkey in seen_w:
            continue
        picked = pick_cip_for_weleda_row(
            formule, forme, contenance, cis_by_code, cip_rows
        )
        if picked is None:
            continue
        cip13, cis = picked
        lines_out.append((wkey, cip13, cis))
        seen_w.add(wkey)

    lines_out.sort(key=lambda x: (int(x[0][1:]) if x[0][1:].isdigit() else 99999, x[0]))

    with out_path.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter=";")
        w.writerow(["formule_w", "cip13", "cis"])
        for wcode, cip13, cis in lines_out:
            w.writerow([wcode, cip13, cis])

    print(f"Écrit {len(lines_out)} lignes → {out_path}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
