#!/usr/bin/env python3
"""
Envoie le CSV généré par bdm_build_libelle_and_csv.py vers la feuille Google Sheets
« médicament 2026-BDM ».

Prérequis :
  pip install gspread google-auth

Configuration :
  1. Google Cloud Console : créer un projet, activer l’API Google Sheets,
     créer un compte de service, télécharger la clé JSON.
  2. Partager le spreadsheet avec l’email du compte de service (éditeur).
  3. Variable d’environnement GOOGLE_APPLICATION_CREDENTIALS = chemin vers le fichier JSON,
     ou option --credentials chemin.

Usage :
  python bdm_upload_to_sheets.py [--csv bdm_total.csv] [--credentials creds.json]
  Par défaut : scripts/bdm_output/bdm_total.csv
"""
from __future__ import annotations

import argparse
import csv
import os
import sys
from pathlib import Path

# ID du spreadsheet et nom de la feuille
SPREADSHEET_ID = "1Tn0zkWjKh6lggWON176wjKM9mhMQ6HYZPbiYIFBxnfo"
SHEET_NAME = "médicament 2026-BDM"


def _col_letter(n: int) -> str:
    """Colonne 1 -> A, 27 -> AA, etc."""
    s = ""
    while n > 0:
        n, r = divmod(n - 1, 26)
        s = chr(65 + r) + s
    return s or "A"


def main() -> None:
    script_dir = Path(__file__).resolve().parent
    default_csv = script_dir / "bdm_output" / "bdm_total.csv"

    parser = argparse.ArgumentParser(description="Envoie bdm_total.csv (ou autre) vers Google Sheets.")
    parser.add_argument(
        "--csv",
        type=Path,
        default=default_csv,
        help=f"Fichier CSV à envoyer (défaut: {default_csv})",
    )
    parser.add_argument(
        "--credentials",
        type=Path,
        default=os.environ.get("GOOGLE_APPLICATION_CREDENTIALS"),
        help="Chemin vers le fichier JSON du compte de service Google",
    )
    args = parser.parse_args()

    if not args.csv.exists():
        print(f"Fichier introuvable: {args.csv}", file=sys.stderr)
        print("Exécutez d'abord: python scripts/bdm_build_libelle_and_csv.py", file=sys.stderr)
        sys.exit(1)

    creds_path = args.credentials
    if not creds_path or not Path(creds_path).exists():
        print(
            "Compte de service Google manquant. Soit :",
            file=sys.stderr,
        )
        print("  export GOOGLE_APPLICATION_CREDENTIALS=/chemin/vers/creds.json", file=sys.stderr)
        print("  soit : --credentials /chemin/vers/creds.json", file=sys.stderr)
        sys.exit(1)

    try:
        import gspread
        from google.oauth2.service_account import Credentials
    except ImportError:
        print("Installez: pip install gspread google-auth", file=sys.stderr)
        sys.exit(1)

    # Lire le CSV (séparateur ;)
    rows = []
    with open(args.csv, "r", encoding="utf-8-sig") as f:
        reader = csv.reader(f, delimiter=";")
        for row in reader:
            rows.append(row)

    if not rows:
        print("CSV vide.", file=sys.stderr)
        sys.exit(1)

    scopes = ["https://www.googleapis.com/auth/spreadsheets"]
    creds = Credentials.from_service_account_file(str(creds_path), scopes=scopes)
    gc = gspread.authorize(creds)

    sh = gc.open_by_key(SPREADSHEET_ID)
    try:
        sheet = sh.worksheet(SHEET_NAME)
    except gspread.WorksheetNotFound:
        sheet = sh.add_worksheet(title=SHEET_NAME, rows=len(rows) + 100, cols=30)

    # Limite ~50k cellules par requête : envoi par lots de 1500 lignes
    sheet.clear()
    batch_size = 1500
    for i in range(0, len(rows), batch_size):
        chunk = rows[i : i + batch_size]
        start = i + 1
        end = i + len(chunk)
        range_a1 = f"A{start}:{_col_letter(len(rows[0]))}{end}"
        sheet.update(range_a1, chunk, value_input_option="USER_ENTERED")
    print(f"Feuille « {SHEET_NAME} » mise à jour : {len(rows)} lignes depuis {args.csv.name}")


if __name__ == "__main__":
    main()
