#!/usr/bin/env python3
"""
Convertit le JSON des groupements Choisir mon Groupement en CSV.

IMPORTANT : Ne colle JAMAIS le JSON dans ce fichier .py !
Le JSON doit etre dans un fichier .json separe.

Usage:
  python scripts/cmg_json_to_csv.py                    # lit cmg_groupements.json
  python scripts/cmg_json_to_csv.py mon_fichier.json   # lit mon_fichier.json
  python scripts/cmg_json_to_csv.py - out.csv         # lit le JSON depuis stdin
"""
from __future__ import annotations

import csv
import json
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_JSON = SCRIPT_DIR / "cmg_groupements.json"
DEFAULT_CSV = SCRIPT_DIR / "cmg_groupements.csv"

FIELDNAMES = [
    "gr_num", "name", "link", "gr_membre",
    "gr_adr1", "gr_adr2", "gr_code", "gr_ville",
    "gr_internet", "gr_note_value", "gr_note", "gr_nbavis", "logo",
]


def main():
    json_arg = sys.argv[1] if len(sys.argv) > 1 else None
    csv_path = Path(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_CSV

    if json_arg == "-":
        raw = sys.stdin.read()
    else:
        json_path = Path(json_arg) if json_arg else DEFAULT_JSON
        if not json_path.exists():
            print("Erreur: fichier JSON introuvable:", json_path)
            print()
            print("Ne colle PAS le JSON dans le fichier .py !")
            print("1. Ouvre un editeur de texte, colle le JSON, enregistre en .json (UTF-8)")
            print("2. Relance: python scripts/cmg_json_to_csv.py chemin/vers/fichier.json")
            sys.exit(1)
        raw = json_path.read_text(encoding="utf-8-sig")

    data = json.loads(raw)

    if not isinstance(data, list):
        print("Erreur: le JSON doit etre un tableau")
        sys.exit(1)

    with csv_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDNAMES, extrasaction="ignore")
        writer.writeheader()
        for row in data:
            if not isinstance(row, dict):
                continue
            out = {k: ("" if row.get(k) is None else str(row.get(k)).strip()) for k in FIELDNAMES}
            writer.writerow(out)

    print("OK:", len(data), "lignes ecrites dans", csv_path)


if __name__ == "__main__":
    main()
