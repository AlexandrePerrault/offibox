#!/usr/bin/env python3
"""
Pipeline Medipim : stream les produits depuis l'API Medipim, extrait CIP13 → libellé (name.fr)
et pousse vers offiboxdata (medipim_labels.csv).

Source : https://platform.medipim.fr/docs/api/v4/
- POST /v4/products/stream : tous les produits actifs, ligne par ligne JSON
- Chaque produit a cip13 (ou identifiants) et name.fr (libellé localisé)

Usage :
  export MEDIPIM_API_KEY=xxx
  export MEDIPIM_API_SECRET=yyy
  python scripts/medipim_labels_pipeline.py [--no-github]

Les libellés Medipim remplaceront ceux de BDM_CIP_QUANTITE / BDPM en ligne 1 des résultats BDM.
"""
from __future__ import annotations

import argparse
import base64
import csv
import io
import json
import os
import sys
from datetime import datetime
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

API_BASE = "https://api.medipim.fr"
STREAM_URL = f"{API_BASE}/v4/products/stream"

GITHUB_OWNER = "AlexandrePerrault"
GITHUB_REPO = "offiboxdata"
GITHUB_BRANCH = "main"
GITHUB_PATH = "medipim_labels.csv"

GITHUB_CONTENTS_SIZE_LIMIT_BYTES = 99 * (1024 * 1024)

DEFAULT_OUTPUT_DIR = Path(__file__).resolve().parent / "medipim_labels_output"

# Body pour stream : produits actifs, tri par id, avec hasContent name.fr
STREAM_BODY = {
    "filter": {"and": [{"status": "active"}, {"hasContent": {"flag": "name", "locale": "fr"}}]},
    "sorting": {"id": "ASC"},
}


def get_auth_header() -> str:
    key = os.environ.get("MEDIPIM_API_KEY", "")
    secret = os.environ.get("MEDIPIM_API_SECRET", "")
    if not key or not secret:
        return ""
    creds = f"{key}:{secret}"
    return "Basic " + base64.b64encode(creds.encode()).decode("ascii")


def _extract_cip13(obj: dict) -> str | None:
    """Extrait le CIP13 du produit (chiffres uniquement, 13 caractères)."""
    for field in ("cip13", "eanGtin13", "ean13"):
        val = obj.get(field)
        if isinstance(val, str):
            digits = "".join(c for c in val if c.isdigit())
            if len(digits) == 13:
                return digits
        if isinstance(val, list) and val:
            for v in val:
                if isinstance(v, str):
                    digits = "".join(c for c in v if c.isdigit())
                    if len(digits) == 13:
                        return digits
    return None


def _extract_name_fr(obj: dict) -> str:
    """Extrait le libellé français (name.fr ou name.fr_FR)."""
    name = obj.get("name") or {}
    if isinstance(name, dict):
        return (name.get("fr") or name.get("fr_FR") or "").strip()
    if isinstance(name, str):
        return name.strip()
    return ""


def stream_products() -> list[tuple[str, str]]:
    """Stream les produits Medipim, retourne [(cip13, libelle), ...]."""
    auth = get_auth_header()
    if not auth:
        print("MEDIPIM_API_KEY et MEDIPIM_API_SECRET requis.", file=sys.stderr)
        return []

    body = json.dumps(STREAM_BODY).encode("utf-8")
    req = Request(
        STREAM_URL,
        data=body,
        headers={
            "Authorization": auth,
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "OffiboxMedipimPipeline/1.0 (https://github.com/AlexandrePerrault/offibox)",
        },
        method="POST",
    )

    out: list[tuple[str, str]] = []
    seen: set[str] = set()
    count = 0
    try:
        with urlopen(req, timeout=3600) as resp:
            for line in resp:
                line = line.decode("utf-8", errors="replace").strip()
                if not line:
                    continue
                try:
                    data = json.loads(line)
                except json.JSONDecodeError:
                    continue
                result = data.get("result") if isinstance(data, dict) else None
                if not result or not isinstance(result, dict):
                    continue
                cip13 = _extract_cip13(result)
                name_fr = _extract_name_fr(result)
                if not cip13 or not name_fr:
                    continue
                if cip13 in seen:
                    continue
                seen.add(cip13)
                out.append((cip13, name_fr))
                count += 1
                if count % 5000 == 0:
                    print(f"  Traité : {count} produits", file=sys.stderr, flush=True)
    except HTTPError as e:
        if e.code == 401:
            print("Erreur 401 : clé API Medipim invalide.", file=sys.stderr)
        else:
            print(f"Erreur HTTP {e.code}: {e.read()}", file=sys.stderr)
        return []
    except URLError as e:
        print(f"Erreur réseau : {e}", file=sys.stderr)
        return []

    return out


def build_csv_content(rows: list[tuple[str, str]], delimiter: str = ";") -> str:
    """Construit le CSV UTF-8, séparateur ;. En-tête : CIP13;Libelle."""
    buf = io.StringIO()
    writer = csv.writer(buf, delimiter=delimiter, lineterminator="\n", quoting=csv.QUOTE_MINIMAL)
    writer.writerow(["CIP13", "Libelle"])
    for cip13, libelle in rows:
        writer.writerow([cip13, libelle])
    return buf.getvalue()


def push_to_github(csv_content: str, token: str) -> None:
    """Pousse le CSV vers offiboxdata."""
    path_encoded = quote(GITHUB_PATH, safe="")
    api_url = f"https://api.github.com/repos/{GITHUB_OWNER}/{GITHUB_REPO}/contents/{path_encoded}"
    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github.v3+json",
        "Content-Type": "application/json",
    }
    req_get = Request(api_url, headers={k: v for k, v in headers.items() if k != "Content-Type"})
    try:
        with urlopen(req_get) as resp:
            data = json.loads(resp.read().decode())
            sha = data.get("sha")
    except Exception:
        sha = None

    content_b64 = base64.b64encode(csv_content.encode("utf-8")).decode("ascii")
    message = f"MAJ {GITHUB_PATH} – {datetime.now().strftime('%Y-%m-%d %H:%M')}"
    payload = {"message": message, "content": content_b64, "branch": GITHUB_BRANCH}
    if sha:
        payload["sha"] = sha

    req_put = Request(
        api_url,
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="PUT",
    )
    with urlopen(req_put) as resp:
        if resp.status not in (200, 201):
            raise RuntimeError(f"GitHub API: {resp.status} {resp.read()}")
    print(f"Export GitHub : {GITHUB_PATH}", file=sys.stderr)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Stream Medipim, extrait CIP13→libellé, exporte vers offiboxdata."
    )
    parser.add_argument("--no-github", action="store_true", help="Ne pas pousser vers GitHub")
    args = parser.parse_args()

    print("Stream produits Medipim (actifs, name.fr)...", file=sys.stderr, flush=True)
    rows = stream_products()
    print(f"  {len(rows)} produits avec CIP13 et libellé FR", file=sys.stderr, flush=True)

    if not rows:
        sys.exit(1)

    csv_content = build_csv_content(rows)
    csv_bytes = csv_content.encode("utf-8")
    size_mb = len(csv_bytes) / (1024 * 1024)

    DEFAULT_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    local_path = DEFAULT_OUTPUT_DIR / "medipim_labels.csv"
    local_path.write_bytes(csv_bytes)
    print(f"  Fichier local : {local_path} ({len(rows)} lignes, {size_mb:.2f} Mo)", file=sys.stderr, flush=True)

    if not args.no_github:
        token = os.environ.get("GITHUB_TOKEN")
        if not token:
            print("GITHUB_TOKEN non défini : export GitHub ignoré.", file=sys.stderr)
        elif len(csv_bytes) > GITHUB_CONTENTS_SIZE_LIMIT_BYTES:
            print(f"  Fichier trop volumineux pour GitHub ({size_mb:.0f} Mo).", file=sys.stderr)
        else:
            push_to_github(csv_content, token)
            print(
                f"  -> https://raw.githubusercontent.com/{GITHUB_OWNER}/{GITHUB_REPO}/{GITHUB_BRANCH}/{quote(GITHUB_PATH, safe='')}",
                file=sys.stderr,
            )

    print("Terminé.")


if __name__ == "__main__":
    main()
