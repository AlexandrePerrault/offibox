#!/usr/bin/env python3
"""
Pipeline Annuaire MSSanté : télécharge l'extraction BAL MSSanté depuis data.gouv.fr,
filtre les BAL personnelles (type PER), extrait RPPS → email et pousse vers offiboxdata.

Source : https://www.data.gouv.fr/datasets/annuaire-sante-extraction-des-bal-mssante
Format source : pipe |, colonnes Type de BAL, Adresse BAL, ..., Identifiant PP (index 3).
On ne garde que les lignes type PER (personnel) avec RPPS non vide.

Usage :
  python scripts/annuaire_mssante_pipeline.py [--url URL] [--no-github]

Exécution quotidienne recommandée (même fréquence que data.gouv : quotidienne).
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

DATASET_SLUG = "annuaire-sante-extraction-des-bal-mssante"
DATASET_PAGE_URL = f"https://www.data.gouv.fr/datasets/{DATASET_SLUG}"
DEFAULT_SOURCE_URL = (
    "https://static.data.gouv.fr/resources/annuaire-sante-extraction-des-bal-mssante/"
    "20260317-031824/extraction-correspondance-mssante.txt"
)

GITHUB_OWNER = "AlexandrePerrault"
GITHUB_REPO = "offiboxdata"
GITHUB_BRANCH = "main"
GITHUB_PATH = "annuaire_mssante_bal.csv"

GITHUB_CONTENTS_SIZE_LIMIT_BYTES = 99 * (1024 * 1024)

DEFAULT_OUTPUT_DIR = Path(__file__).resolve().parent / "annuaire_mssante_output"

# Colonnes : Type de BAL (0), Adresse BAL (1), Type Identifiant PP (2), Identifiant PP (3)
COL_TYPE = 0
COL_EMAIL = 1
COL_RPPS = 3
TYPE_PERSONNEL = "PER"


def get_latest_mssante_url() -> str | None:
    """Récupère l'URL actuelle du fichier extraction-correspondance-mssante via l'API data.gouv.fr."""
    api_url = f"https://www.data.gouv.fr/api/1/datasets/{DATASET_SLUG}/"
    try:
        req = Request(api_url, headers={"Accept": "application/json"})
        with urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode())
    except (HTTPError, URLError, json.JSONDecodeError, OSError):
        return None
    resources = data.get("resources") or []
    for r in resources:
        title = (r.get("title") or "").lower()
        if "extraction-correspondance-mssante" in title or "mssante" in title:
            raw_url = r.get("url")
            if raw_url and isinstance(raw_url, str):
                return raw_url.strip()
    return None


def download_source(url: str, progress_mb_interval: float = 20.0) -> bytes:
    """Télécharge le fichier source en flux avec affichage de progression."""
    with urlopen(url, timeout=600) as resp:
        chunk_list = []
        total = 0
        next_report = progress_mb_interval * (1024 * 1024)
        while True:
            chunk = resp.read(1024 * 1024)
            if not chunk:
                break
            chunk_list.append(chunk)
            total += len(chunk)
            if total >= next_report:
                print(f"  Téléchargé : {total / (1024 * 1024):.0f} Mo", file=sys.stderr, flush=True)
                next_report = total + progress_mb_interval * (1024 * 1024)
        raw = b"".join(chunk_list)
    print(f"  Total : {len(raw) / (1024 * 1024):.1f} Mo", file=sys.stderr, flush=True)
    return raw


def decode_and_clean_raw(raw: bytes) -> str:
    """Décode en UTF-8 (avec BOM) ou Latin-1."""
    if raw.startswith(b"\xef\xbb\xbf"):
        text = raw[3:].decode("utf-8")
    else:
        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError:
            text = raw.decode("latin-1")
    return text.replace("\r\n", "\n").replace("\r", "\n").strip()


def extract_personal_bal(text: str) -> list[tuple[str, str]]:
    """
    Parse le fichier pipe-separated, filtre type PER, retourne [(rpps, email), ...].
    """
    lines = text.split("\n")
    if not lines:
        return []
    out: list[tuple[str, str]] = []
    seen: set[tuple[str, str]] = set()
    for line in lines[1:]:
        parts = line.split("|")
        if len(parts) <= max(COL_TYPE, COL_EMAIL, COL_RPPS):
            continue
        bal_type = (parts[COL_TYPE] or "").strip()
        if bal_type != TYPE_PERSONNEL:
            continue
        rpps = (parts[COL_RPPS] or "").strip()
        email = (parts[COL_EMAIL] or "").strip()
        if not rpps or not email or "@" not in email:
            continue
        key = (rpps, email)
        if key in seen:
            continue
        seen.add(key)
        out.append((rpps, email))
    return out


def build_rpps_to_email_map(rows: list[tuple[str, str]]) -> list[tuple[str, str]]:
    """Un RPPS → une email (la première rencontrée)."""
    by_rpps: dict[str, str] = {}
    for rpps, email in rows:
        if rpps not in by_rpps:
            by_rpps[rpps] = email
    return [(r, e) for r, e in sorted(by_rpps.items())]


def build_csv_content(rows: list[tuple[str, str]], delimiter: str = ";") -> str:
    """Construit le contenu CSV (UTF-8, séparateur ;). En-tête : RPPS;Email."""
    buf = io.StringIO()
    writer = csv.writer(buf, delimiter=delimiter, lineterminator="\n", quoting=csv.QUOTE_MINIMAL)
    writer.writerow(["RPPS", "Email"])
    for rpps, email in rows:
        writer.writerow([rpps, email])
    return buf.getvalue()


def push_to_github(csv_content: str, token: str) -> None:
    """Envoie le CSV vers le dépôt GitHub."""
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
    print(f"Export GitHub : {GITHUB_PATH} ({GITHUB_OWNER}/{GITHUB_REPO} {GITHUB_BRANCH}).")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Télécharge l'extraction BAL MSSanté, filtre PER, exporte RPPS→email vers offiboxdata."
    )
    parser.add_argument("--url", default=DEFAULT_SOURCE_URL, help="URL du fichier extraction-correspondance-mssante.txt")
    parser.add_argument("--no-github", action="store_true", help="Ne pas pousser vers GitHub")
    args = parser.parse_args()

    print("Téléchargement extraction BAL MSSanté...", file=sys.stderr, flush=True)
    url = args.url
    try:
        raw = download_source(url)
    except HTTPError as e:
        if e.code != 404:
            raise
        if url != DEFAULT_SOURCE_URL:
            raise
        print("URL par défaut invalide (404). Récupération de l'URL actuelle...", file=sys.stderr, flush=True)
        latest = get_latest_mssante_url()
        if latest:
            print(f"  Nouvelle URL : {latest[:80]}...", file=sys.stderr, flush=True)
            raw = download_source(latest)
        else:
            print(
                f"Impossible de récupérer l'URL.\n"
                f"Dataset : {DATASET_PAGE_URL}\n"
                f"Téléchargez extraction-correspondance-mssante.txt et relancez avec --url <URL>",
                file=sys.stderr,
            )
            sys.exit(1)

    print("Décodage et extraction BAL personnelles (type PER)...", file=sys.stderr, flush=True)
    text = decode_and_clean_raw(raw)
    del raw
    rows = extract_personal_bal(text)
    del text
    print(f"  {len(rows)} lignes BAL personnelles (RPPS+email)", file=sys.stderr, flush=True)

    mapped = build_rpps_to_email_map(rows)
    print(f"  {len(mapped)} RPPS uniques avec email MSSanté", file=sys.stderr, flush=True)

    csv_content = build_csv_content(mapped)
    csv_bytes = csv_content.encode("utf-8")
    size_mb = len(csv_bytes) / (1024 * 1024)

    DEFAULT_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    local_path = DEFAULT_OUTPUT_DIR / "annuaire_mssante_bal.csv"
    local_path.write_bytes(csv_bytes)
    print(f"  Fichier local : {local_path} ({len(mapped)} lignes, {size_mb:.2f} Mo)", file=sys.stderr, flush=True)

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
