#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Fusion CSV nomenclature LPP (codes + URL) avec les données LPPTOT (libellé, tarif, prix, date).

Entrée nomenclature : CSV avec colonnes CODE_LPP, URL_AMELI.
  - CODE_LPP au format "(CODE LPP) 1100028" → on garde uniquement le code (1100028).
  - URL_AMELI conservée telle quelle.

Données LPPTOT (ZIP CNAM) : source http://www.codage.ext.cnamts.fr/codif/tips/download_file.php?filename=tips/LPPTOT871.zip
  - Libellé, Tarif, Prix unitaire réglementé, Date début validité (dernière période par code).

Sortie CSV (séparateur ;) :
  A : Code LPP (sans texte)
  B : Libellé
  C : URL
  D : Tarif
  E : Prix unitaire réglementé
  F : Date début validité (la toute dernière)

Usage :
  python tool/lpp_nomenclature_merge.py "C:\\Users\\perra\\Downloads\\codes LPP +++ - nomenclature LPP.csv" -o lpp_nomenclature_out.csv
  python tool/lpp_nomenclature_merge.py nomenclature.csv --lpptot "C:\\Users\\perra\\Downloads\\LPPTOT871_extract" -o out.csv
  python tool/lpp_nomenclature_merge.py nomenclature.csv --lpptot LPPTOT871.zip -o out.csv
  python tool/lpp_nomenclature_merge.py nomenclature.csv --lpptot-url -o out.csv
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
import zipfile
from pathlib import Path
from urllib.request import urlretrieve

# Réutilisation de la logique d'extraction LPPTOT
ENCODING = "cp1252"
TARIF_PATTERN = re.compile(rb"0{8,}(\d{5})\d*")
DATE_PATTERN = re.compile(rb"(20\d{6})")

LPPTOT_URL = "http://www.codage.ext.cnamts.fr/codif/tips/download_file.php?filename=tips/LPPTOT871.zip"


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
    # Dossier d'extraction (ex: C:\Users\perra\Downloads\LPPTOT871_extract) → lire le fichier LPPTOT871
    if p.is_dir():
        lpp_file = p / "LPPTOT871"
        if not lpp_file.exists():
            # Fallback : premier fichier non .py dans le dossier
            for f in sorted(p.iterdir()):
                if f.is_file() and f.suffix.lower() != ".py":
                    lpp_file = f
                    break
            else:
                raise FileNotFoundError(f"Aucun fichier LPPTOT871 dans {p}")
        with open(lpp_file, "rb") as f:
            return f.read()
    if zipfile.is_zipfile(path):
        with zipfile.ZipFile(path, "r") as z:
            names = z.namelist()
            if not names:
                raise ValueError("ZIP vide")
            with z.open(names[0]) as f:
                return f.read()
    with open(path, "rb") as f:
        return f.read()


def parse_lpptot_records(data: bytes) -> dict[str, dict]:
    """
    Parse le contenu binaire LPPTOT. Retourne un dict code_lpp (7 chiffres) -> { libelle, tarif, prix_unitaire_reglemente, date_debut_validite }.
    Un seul enregistrement par code : celui dont la date de validité est la plus récente.
    """
    seen_codes: dict[str, list[dict]] = {}
    pos = 0
    current_code: str | None = None
    current_libelle: str = ""

    while True:
        idx = data.find(b"11001", pos)
        if idx < 0:
            break
        block = data[idx : idx + 120]
        tarif = extract_tarif_from_block(block)
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
            "tarif": tarif,
            "prix_unitaire_reglemente": 0.0,
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


def parse_nomenclature_csv(path: str) -> list[tuple[str, str]]:
    """Lit le CSV nomenclature. Retourne [(code_7_chiffres, url), ...]."""
    rows = []
    with open(path, "r", encoding="utf-8-sig", newline="", errors="replace") as f:
        reader = csv.reader(f)
        header = next(reader, None)
        for row in reader:
            if len(row) < 2:
                continue
            raw_code = (row[0] or "").strip()
            url = (row[1] or "").strip()
            # "(CODE LPP) 1100028" -> 1100028
            match = re.search(r"(\d{7})", raw_code)
            if match:
                code = match.group(1)
                rows.append((code, url))
    return rows


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Fusion CSV nomenclature LPP (code+URL) avec LPPTOT (libellé, tarif, date)"
    )
    ap.add_argument(
        "nomenclature_csv",
        help="Fichier CSV nomenclature (colonnes CODE_LPP, URL_AMELI)",
    )
    ap.add_argument(
        "-o",
        "--output",
        default="lpp_nomenclature_merged.csv",
        help="Fichier CSV de sortie (séparateur ;)",
    )
    ap.add_argument(
        "--lpptot",
        metavar="PATH",
        default=None,
        help="Fichier ZIP, fichier binaire LPPTOT871, ou dossier d'extraction (ex: C:\\Users\\perra\\Downloads\\LPPTOT871_extract). Si absent, seuls code et URL sont exportés.",
    )
    ap.add_argument(
        "--lpptot-url",
        action="store_true",
        help="Télécharger LPPTOT depuis l'URL CNAM (LPPTOT871.zip) et l'utiliser pour la fusion.",
    )
    args = ap.parse_args()

    nomenclature_path = Path(args.nomenclature_csv)
    if not nomenclature_path.exists():
        print(f"Fichier introuvable: {nomenclature_path}", file=sys.stderr)
        sys.exit(1)

    nomenclature = parse_nomenclature_csv(args.nomenclature_csv)
    print(f"Nomenclature: {len(nomenclature)} lignes lues.")

    lpptot_by_code: dict[str, dict] = {}
    if args.lpptot_url or args.lpptot:
        if args.lpptot_url:
            zip_path = Path("LPPTOT871.zip")
            print(f"Téléchargement de {LPPTOT_URL} ...")
            urlretrieve(LPPTOT_URL, zip_path)
            data = read_lpp_file(str(zip_path))
            if zip_path.exists():
                zip_path.unlink()
        else:
            data = read_lpp_file(args.lpptot)
        lpptot_by_code = parse_lpptot_records(data)
        print(f"LPPTOT: {len(lpptot_by_code)} codes avec tarif/date.")

    sep = ";"
    outpath = Path(args.output)
    outpath.parent.mkdir(parents=True, exist_ok=True)

    def format_num(v):
        if v is None or v == "" or (isinstance(v, float) and v == 0.0):
            return ""
        if isinstance(v, (int, float)):
            return f"{v:.2f}".replace(".", ",")
        return str(v)

    with open(outpath, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter=sep)
        w.writerow([
            "Code LPP",
            "Libellé",
            "URL",
            "Tarif",
            "Prix unitaire réglementé",
            "Date début validité",
        ])
        for code, url in nomenclature:
            extra = lpptot_by_code.get(code, {})
            libelle = extra.get("libelle") or ""
            tarif = extra.get("tarif")
            pur = extra.get("prix_unitaire_reglemente")
            if pur == 0.0 and tarif is not None:
                pur = tarif
            date_debut = extra.get("date_debut_validite") or ""
            w.writerow([
                code,
                libelle,
                url,
                format_num(tarif),
                format_num(pur),
                date_debut,
            ])

    print(f"Exporté {len(nomenclature)} lignes vers {outpath}")


if __name__ == "__main__":
    main()
