#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Pipeline LPP simplifié : codes (Google Sheet ou CSV) + LPPTOT867 → CSV 3 colonnes.

Entrée des codes :
  - Feuille Google "nomenclature LPP" du fichier 1AeLBTlGfjXQdoC3ORGXVkiuRN4Wz_5ICYJGYk2lyV2A, colonne A.
  - Ou fichier CSV (export de cette feuille) : colonne A = codes (on enlève "(CODE LPP)" pour garder le code à 7 chiffres).

Source LPPTOT : LPPTOT867.zip
  http://www.codage.ext.cnamts.fr/codif/tips/download_file.php?filename=tips/LPPTOT867.zip

Sortie CSV (séparateur ;) :
  A : code à 7 chiffres
  B : libellé (depuis LPPTOT)
  C : url (calculée) = http://www.codage.ext.cnamts.fr/cgi/tips/cgi-fiche?p_code_tips={CODE}&p_date_jo_arrete=%25&p_menu=FICHE&p_site=AMELI

Usage :
  # Avec export CSV de la feuille "nomenclature LPP" (col A)
  python tool/lpp_pipeline_simple.py --csv "nomenclature LPP.csv" -o lpp_export.csv

  # Depuis Google Sheet (optionnel : pip install gspread google-auth ; credentials requis)
  python tool/lpp_pipeline_simple.py --google-sheet 1AeLBTlGfjXQdoC3ORGXVkiuRN4Wz_5ICYJGYk2lyV2A --sheet "nomenclature LPP" -o lpp_export.csv

  # LPPTOT local (ZIP ou fichier extrait) au lieu du téléchargement
  python tool/lpp_pipeline_simple.py --csv codes.csv --lpptot LPPTOT867.zip -o out.csv
"""

from __future__ import annotations

import argparse
import csv
import os
import re
import sys
import zipfile
from pathlib import Path
from urllib.request import urlretrieve

# Encodage LPPTOT
ENCODING = "cp1252"
LPPTOT_URL = "http://www.codage.ext.cnamts.fr/codif/tips/download_file.php?filename=tips/LPPTOT867.zip"
URL_TEMPLATE = "http://www.codage.ext.cnamts.fr/cgi/tips/cgi-fiche?p_code_tips={code}&p_date_jo_arrete=%25&p_menu=FICHE&p_site=AMELI"

# Patterns réutilisés depuis lpp_dbf_to_sheets
TARIF_PATTERN = re.compile(rb"0{8,}(\d{5})\d*")
DATE_PATTERN = re.compile(rb"(20\d{6})")


def extract_tarif_from_block(block: bytes) -> float | None:
    m = TARIF_PATTERN.search(block)
    if not m:
        return None
    raw = int(m.group(1))
    if raw >= 10000:
        return round(raw / 10000.0, 2)
    return round(raw / 100.0, 2)


def extract_dates_from_block(block: bytes) -> tuple[str | None, str | None]:
    dates = DATE_PATTERN.findall(block)
    if len(dates) >= 2:
        d1 = dates[0].decode("ascii")
        d2 = dates[1].decode("ascii")
        return (_format_date(d1), _format_date(d2))
    return (None, None)


def _format_date(yyyymmdd: str) -> str:
    if len(yyyymmdd) != 8:
        return yyyymmdd
    return f"{yyyymmdd[6:8]}/{yyyymmdd[4:6]}/{yyyymmdd[0:4]}"


def read_lpp_file(path: str) -> bytes:
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(path)
    if p.is_dir():
        for name in ("LPPTOT867", "LPPTOT871"):
            f = p / name
            if f.exists():
                return f.read_bytes()
        for f in sorted(p.iterdir()):
            if f.is_file() and f.suffix.lower() != ".py":
                return f.read_bytes()
        raise FileNotFoundError(f"Aucun fichier LPPTOT dans {p}")
    if zipfile.is_zipfile(path):
        with zipfile.ZipFile(path, "r") as z:
            names = z.namelist()
            if not names:
                raise ValueError("ZIP vide")
            with z.open(names[0]) as f:
                return f.read()
    return p.read_bytes()


def parse_lpptot_records(data: bytes) -> dict[str, dict]:
    """Parse LPPTOT. Retourne code (7 chiffres) -> { libelle, ... } (dernière période par code)."""
    seen_codes: dict[str, list[dict]] = {}
    pos = 0
    current_code: str | None = None
    current_libelle: str = ""

    while True:
        idx = data.find(b"11001", pos)
        if idx < 0:
            break
        block = data[idx : idx + 120]
        date_debut, date_fin = extract_dates_from_block(block)

        before = data[max(0, idx - 800) : idx]
        code_match = re.search(rb"(?<!\d)(\d{7})(?!\d)", before)
        if code_match:
            current_code = code_match.group(1).decode("ascii")
        if not current_code:
            long_code = re.search(rb"(\d{10,11})\s+", before)
            if long_code:
                raw = long_code.group(1).decode("ascii").strip()
                current_code = raw[-7:] if len(raw) >= 7 else raw

        try:
            before_str = before.decode(ENCODING, errors="replace")
        except Exception:
            before_str = before.decode("latin-1", errors="replace")
        lib_match = re.search(
            r"\d{10,11}\s+[\d\s]{0,20}([A-Za-z\u00c0-\u00ff][\w\s,.;\'\-\u00c0-\u00ff]{20,200}?)\s{2,}",
            before_str,
        )
        if lib_match:
            current_libelle = lib_match.group(1).strip()

        if not current_code:
            pos = idx + 1
            continue

        row = {
            "libelle": current_libelle or "",
            "date_debut_validite": date_debut,
            "date_fin_validite": date_fin,
        }
        seen_codes.setdefault(current_code, []).append(row)
        pos = idx + 1

    def _date_key(r: dict) -> tuple:
        fin = r.get("date_fin_validite") or ""
        deb = r.get("date_debut_validite") or ""

        def parse_jm(a: str) -> tuple:
            if not a or len(a) != 10:
                return (0, 0, 0)
            parts = a.split("/")
            if len(parts) != 3:
                return (0, 0, 0)
            try:
                return (int(parts[2]), int(parts[1]), int(parts[0]))
            except ValueError:
                return (0, 0, 0)

        return (parse_jm(fin), parse_jm(deb))

    result: dict[str, dict] = {}
    for code, rows in seen_codes.items():
        if not rows:
            continue
        sorted_rows = sorted(rows, key=_date_key, reverse=True)
        best = sorted_rows[0].copy()
        for r in rows:
            lb = (r.get("libelle") or "").strip()
            if lb and len(lb) > len(best.get("libelle") or ""):
                best["libelle"] = r["libelle"]
        result[code] = best
    return result


def codes_from_csv(path: str) -> list[str]:
    """Lit les codes LPP depuis un CSV (colonne A). Enlève '(CODE LPP)' et garde le code à 7 chiffres."""
    codes: list[str] = []
    with open(path, "r", encoding="utf-8-sig", newline="", errors="replace") as f:
        reader = csv.reader(f)
        for row in reader:
            raw = (row[0] or "").strip() if row else ""
            m = re.search(r"(\d{7})", raw)
            if m:
                codes.append(m.group(1))
    return codes


def codes_from_google_sheet(spreadsheet_id: str, sheet_name: str) -> list[str]:
    """Lit la colonne A de la feuille Google Sheet. Nécessite gspread + credentials."""
    try:
        import gspread
        from google.oauth2.service_account import Credentials
    except ImportError:
        raise RuntimeError(
            "Pour --google-sheet, installez: pip install gspread google-auth. "
            "Et configurez GOOGLE_APPLICATION_CREDENTIALS (fichier JSON service account)."
        )
    scopes = ["https://www.googleapis.com/auth/spreadsheets.readonly"]
    creds = Credentials.from_service_account_file(
        Path(os.environ.get("GOOGLE_APPLICATION_CREDENTIALS", "")).expanduser(),
        scopes=scopes,
    )
    gc = gspread.authorize(creds)
    sh = gc.open_by_key(spreadsheet_id)
    ws = sh.worksheet(sheet_name)
    rows = ws.col_values(1)
    codes = []
    for raw in rows[1:] if rows else []:  # skip header
        raw = (raw or "").strip()
        m = re.search(r"(\d{7})", raw)
        if m:
            codes.append(m.group(1))
    return codes


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Pipeline LPP : codes (CSV ou Google Sheet) + LPPTOT867 -> CSV code, libelle, url"
    )
    ap.add_argument(
        "--csv",
        metavar="PATH",
        help="Fichier CSV export de la feuille 'nomenclature LPP' (colonne A = codes). Enlève '(CODE LPP)' pour garder le code 7 chiffres.",
    )
    ap.add_argument(
        "--google-sheet",
        metavar="ID",
        help="ID du Google Sheet (ex: 1AeLBTlGfjXQdoC3ORGXVkiuRN4Wz_5ICYJGYk2lyV2A). Nécessite gspread + GOOGLE_APPLICATION_CREDENTIALS.",
    )
    ap.add_argument(
        "--sheet",
        default="nomenclature LPP",
        help="Nom de la feuille (défaut: nomenclature LPP)",
    )
    ap.add_argument(
        "-o",
        "--output",
        default="lpp_nomenclature_3cols.csv",
        help="Fichier CSV de sortie (séparateur ;)",
    )
    ap.add_argument(
        "--lpptot",
        metavar="PATH",
        default=None,
        help="Fichier LPPTOT867 (ZIP ou binaire) ou dossier d'extraction. Par défaut : téléchargement depuis l'URL CNAM.",
    )
    ap.add_argument(
        "--all",
        action="store_true",
        help="Extraire tous les codes LPP du fichier LPPTOT (pas de liste en entrée). Sortie CSV : code, libellé, url.",
    )
    args = ap.parse_args()

    # LPPTOT : télécharger ou lire localement en premier si --all
    if args.lpptot:
        data = read_lpp_file(args.lpptot)
    else:
        zip_path = Path("LPPTOT867.zip")
        print(f"Téléchargement de {LPPTOT_URL} ...")
        urlretrieve(LPPTOT_URL, zip_path)
        data = read_lpp_file(str(zip_path))
        if zip_path.exists():
            zip_path.unlink()
    lpptot = parse_lpptot_records(data)
    print(f"LPPTOT : {len(lpptot)} codes avec libellé.")

    if args.all:
        codes = sorted(lpptot.keys())
        print(f"Mode --all : export de tous les {len(codes)} codes.")
    elif args.csv:
        codes = codes_from_csv(args.csv)
        print(f"Codes lus depuis CSV : {len(codes)}")
    elif args.google_sheet:
        if not os.environ.get("GOOGLE_APPLICATION_CREDENTIALS"):
            print("GOOGLE_APPLICATION_CREDENTIALS doit pointer vers le fichier JSON du service account.", file=sys.stderr)
            sys.exit(1)
        codes = codes_from_google_sheet(args.google_sheet, args.sheet)
        print(f"Codes lus depuis Google Sheet : {len(codes)}")
    else:
        print("Indiquez --all (tous les codes LPPTOT), --csv <fichier> ou --google-sheet <spreadsheet_id>.", file=sys.stderr)
        sys.exit(1)

    if not codes:
        print("Aucun code à exporter.", file=sys.stderr)
        sys.exit(1)

    outpath = Path(args.output)
    outpath.parent.mkdir(parents=True, exist_ok=True)
    with open(outpath, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter=";")
        w.writerow(["code à 7 chiffres", "libellé", "url"])
        for code in codes:
            rec = lpptot.get(code, {})
            libelle = rec.get("libelle") or ""
            url = URL_TEMPLATE.format(code=code)
            w.writerow([code, libelle, url])

    print(f"Exporté {len(codes)} lignes vers {outpath}")


if __name__ == "__main__":
    main()
