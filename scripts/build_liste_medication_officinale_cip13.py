#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Génère liste_medication_officinale_cip13.csv à partir du XLS ANSM (médicaments
en accès direct / médication officinale). Ce CSV est utilisé par Offibox pour
le badge "OTC/Libre accès" (commonspan) en ligne 1 des résultats BDM.

Source : https://ansm.sante.fr/documents/reference/medicaments-en-acces-direct
Fichier XLS : mis à jour mensuellement par l'ANSM (URL avec date, ex. décembre 2025).

Usage:
  python build_liste_medication_officinale_cip13.py [--xls URL_ou_chemin] [--out fichier.csv]
  Sans argument : télécharge le XLS depuis l'URL par défaut et écrit dans le répertoire courant.

Dépendances: pip install requests xlrd
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# URL type (à mettre à jour si l'ANSM change le chemin ; page de référence ci-dessus)
DEFAULT_XLS_URL = "https://ansm.sante.fr/uploads/2025/12/22/20251222-liste-medication-officinale-listecomplete-decembre-2025.xls"
OUTPUT_FILENAME = "liste_medication_officinale_cip13.csv"
# Colonne D = index 3 (0-based) dans le XLS ANSM pour le code CIP 13 chiffres
CIP13_COLUMN_INDEX = 3
CIP13_RE = re.compile(r"\d{13}")


def extract_cip13_from_cell(value) -> str | None:
    if value is None:
        return None
    s = str(value).strip()
    # Supprimer espaces/guillemets et garder uniquement les chiffres
    digits = re.sub(r"\D", "", s)
    if len(digits) == 13:
        return digits
    # Parfois le CIP est en format "34009352713345" dans une chaîne plus longue
    m = CIP13_RE.search(s)
    if m:
        return m.group(0)
    return None


def read_xls_path(path: Path):
    try:
        import xlrd
    except ImportError:
        print("Dépendance manquante: pip install xlrd", file=sys.stderr)
        sys.exit(1)
    with open(path, "rb") as f:
        content = f.read()
    return read_xls_bytes(content)


def read_xls_bytes(content: bytes):
    try:
        import xlrd
    except ImportError:
        print("Dépendance manquante: pip install xlrd", file=sys.stderr)
        sys.exit(1)
    # xlrd ouvre .xls (Excel 97-2003)
    book = xlrd.open_workbook(file_contents=content)
    sheet = book.sheet_by_index(0)
    cips = set()
    for row_idx in range(sheet.nrows):
        if sheet.ncols <= CIP13_COLUMN_INDEX:
            continue
        cell = sheet.cell(row_idx, CIP13_COLUMN_INDEX)
        val = cell.value
        cip = extract_cip13_from_cell(val)
        if cip:
            cips.add(cip)
    return sorted(cips)


def download_xls(url: str, timeout: int = 60) -> bytes:
    try:
        import requests
    except ImportError:
        print("Dépendance manquante: pip install requests", file=sys.stderr)
        sys.exit(1)
    r = requests.get(url, timeout=timeout)
    r.raise_for_status()
    return r.content


def main():
    parser = argparse.ArgumentParser(
        description="Génère liste_medication_officinale_cip13.csv depuis le XLS ANSM (col D = CIP13)."
    )
    parser.add_argument(
        "--xls",
        default=DEFAULT_XLS_URL,
        help="URL du XLS ANSM ou chemin local vers un fichier .xls",
    )
    parser.add_argument(
        "--out",
        default=OUTPUT_FILENAME,
        help=f"Fichier CSV de sortie (défaut: {OUTPUT_FILENAME})",
    )
    args = parser.parse_args()
    xls_arg = args.xls.strip()
    out_path = Path(args.out)

    if xls_arg.startswith("http://") or xls_arg.startswith("https://"):
        print(f"Téléchargement de {xls_arg}...")
        content = download_xls(xls_arg)
        cips = read_xls_bytes(content)
    else:
        path = Path(xls_arg)
        if not path.exists():
            print(f"Fichier introuvable: {path}", file=sys.stderr)
            sys.exit(1)
        cips = read_xls_path(path)

    out_path.write_text("\n".join(cips) + "\n", encoding="utf-8")
    print(f"Ecrit {len(cips)} CIP13 dans {out_path}")
    print(f"A copier a la racine du depot offiboxdata sous le nom {OUTPUT_FILENAME}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
