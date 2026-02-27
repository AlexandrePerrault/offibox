#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Extraction LPP depuis le fichier LPPTOT (.dbf ou fichier extrait du ZIP)
vers un CSV prêt pour Google Sheets.

Colonnes exportées :
  A : Code LPP
  B : Libellé
  C : Tarif (dernier tarif uniquement)
  D : Prix unitaire réglementé (0 si Néant ou absent)
  E : Date début validité
  F : Date fin validité (si elle existe uniquement)

Usage :
  python tool/lpp_dbf_to_sheets.py "<chemin vers ZIP ou fichier .dbf>"
  python tool/lpp_dbf_to_sheets.py <fichier> --output lpp_sheets.csv
  python tool/lpp_dbf_to_sheets.py --url --output lpp_sheets.csv  # fetch depuis LPPTOT867
"""

from __future__ import annotations

import argparse
import csv
import io
import os
import re
import struct
import zipfile
from pathlib import Path
from typing import BinaryIO
from urllib.request import urlopen


# Encodage pour le libellé (caractères français)
ENCODING = "cp1252"

# URL par défaut du ZIP LPPTOT (ex: LPPTOT867)
DEFAULT_LPP_ZIP_URL = "http://www.codage.ext.cnamts.fr/codif/tips/download_file.php?filename=tips/LPPTOT867.zip"

# Positions / patterns déduits du format LPPTOT (blocs type 11001...)
# Dans un bloc : ...YYYYMMDDYYYYMMDD... puis après une séquence de 0, tarif 5 chiffres (ex: 41513 = 4,15 €)
TARIF_PATTERN = re.compile(rb"0{8,}(\d{5})\d*")  # 8 zéros ou plus puis 5 chiffres = tarif (41513 → 4,15 €)
DATE_PATTERN = re.compile(rb"(20\d{6})")  # YYYYMMDD


def extract_tarif_from_block(block: bytes) -> float | None:
    """Extrait le tarif (en euros) d'un bloc type 11001... ex: 41513 → 4.15."""
    m = TARIF_PATTERN.search(block)
    if not m:
        return None
    raw = int(m.group(1))
    # 41513 → 4,15 €  (5 chiffres : centimes ou format XXXYY)
    if raw >= 10000:
        return round(raw / 10000.0, 2)
    return round(raw / 100.0, 2)


def extract_dates_from_block(block: bytes) -> tuple[str | None, str | None]:
    """Extrait date début et date fin validité (YYYYMMDD → JJ/MM/AAAA)."""
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


def fetch_lpp_from_url(url: str = DEFAULT_LPP_ZIP_URL) -> bytes:
    """Télécharge le ZIP LPPTOT depuis l'URL et retourne le contenu du premier fichier."""
    with urlopen(url, timeout=60) as resp:
        raw = resp.read()
    bio = io.BytesIO(raw)
    if not zipfile.is_zipfile(bio):
        raise ValueError("La réponse n'est pas un ZIP valide")
    bio.seek(0)
    with zipfile.ZipFile(bio, "r") as z:
        names = z.namelist()
        if not names:
            raise ValueError("ZIP vide")
        with z.open(names[0]) as f:
            return f.read()


def read_lpp_file(path: str) -> bytes:
    """Lit le fichier LPP : si c'est un ZIP, extrait le premier fichier (sans extension)."""
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(path)
    if zipfile.is_zipfile(path):
        with zipfile.ZipFile(path, "r") as z:
            names = z.namelist()
            if not names:
                raise ValueError("ZIP vide")
            with z.open(names[0]) as f:
                return f.read()
    with open(path, "rb") as f:
        return f.read()


def parse_records(data: bytes) -> list[dict]:
    """
    Parse le contenu binaire LPPTOT (format fixe / pseudo-DBF).
    Retourne une liste de dicts avec : code_lpp, libelle, tarif, prix_unitaire_reglemente,
    date_debut_validite, date_fin_validite.
    On ne garde que le dernier tarif par code LPP.
    """
    # Recherche des blocs "11001" qui contiennent les tarifs et dates
    block_start = data.find(b"11001")
    if block_start < 0:
        # Fallback : tout le fichier comme un seul bloc
        block_start = 0

    # Par code LPP on collecte toutes les lignes (tarif + dates), puis on ne garde que le dernier tarif
    # en fonction de la date de validité (date fin validité la plus récente, ou date début si pas de fin).
    seen_codes: dict[str, list[dict]] = {}  # code_lpp -> liste des enregistrements (tarif + dates)
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
        prix_unitaire_reglemente = 0.0

        before = data[max(0, idx - 800) : idx]
        code_match = re.search(rb"(?<!\d)(\d{7})(?!\d)", before)
        if code_match:
            current_code = code_match.group(1).decode("ascii")
        if not current_code:
            long_code = re.search(rb"(\d{10,11})\s+", before)
            if long_code:
                current_code = long_code.group(1).decode("ascii").strip()

        try:
            before_str = before.decode(ENCODING, errors="replace")
        except Exception:
            before_str = before.decode("latin-1", errors="replace")
        lib_match = re.search(r"\d{10,11}\s+[\d\s]{0,20}([A-Za-z\u00c0-\u00ff][\w\s,.;\'\-\u00c0-\u00ff]{20,200}?)\s{2,}", before_str)
        if lib_match:
            current_libelle = lib_match.group(1).strip()

        if not current_code:
            pos = idx + 1
            continue

        row = {
            "code_lpp": current_code,
            "libelle": current_libelle or "",
            "tarif": tarif,
            "prix_unitaire_reglemente": prix_unitaire_reglemente,
            "date_debut_validite": date_debut,
            "date_fin_validite": date_fin,
        }
        seen_codes.setdefault(current_code, []).append(row)
        pos = idx + 1

    # Pour chaque code : garder uniquement le dernier tarif selon la date de validité (date fin, sinon date début)
    def _date_key(r: dict) -> tuple:
        fin = r.get("date_fin_validite") or ""
        deb = r.get("date_debut_validite") or ""
        # JJ/MM/AAAA -> (AAAA, MM, JJ) pour tri
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

    result: list[dict] = []
    for code, rows in seen_codes.items():
        if not rows:
            continue
        # Tri par date fin validité décroissante, puis date début
        sorted_rows = sorted(rows, key=_date_key, reverse=True)
        best = sorted_rows[0]
        # Garder le libellé le plus long (souvent le premier enregistrement a le libellé)
        for r in rows:
            if (r.get("libelle") or "").strip() and len((r.get("libelle") or "")) > len(best.get("libelle") or ""):
                best = {**best, "libelle": r["libelle"]}
        result.append(best)
    return result


def parse_records_v2(data: bytes) -> list[dict]:
    """
    Version alternative : parcours séquentiel par enregistrements fixes.
    Structure observée : en-tête ~82 octets puis enregistrements avec code 11 car, libellé, puis blocs tarifaires.
    """
    RECORD_HEADER = 82
    results: dict[str, dict] = {}
    pos = RECORD_HEADER
    size = len(data)

    while pos < size - 50:
        # Code LPP : 11 caractères (ex 008711E2001)
        code_raw = data[pos : pos + 11]
        if not code_raw.strip(b" 0"):
            pos += 1
            continue
        code_lpp = code_raw.decode("ascii", errors="replace").strip()
        if len(code_lpp) < 7:
            pos += 1
            continue
        # Code 7 chiffres pour Sheets (parfois le fichier a 10-11 chiffres)
        if len(code_lpp) > 7:
            code_lpp = code_lpp[-7:] if code_lpp.isdigit() else code_lpp[:7]

        pos += 11
        # Espaces puis zone chiffres (ex 10101011100028)
        pos += 20
        # Libellé : jusqu'à une longue séquence de chiffres ou 10102...
        lib_end = pos
        while lib_end < min(pos + 260, size):
            chunk = data[lib_end : lib_end + 40]
            if re.match(rb"^\d{10,}", chunk):
                break
            lib_end += 1
        try:
            libelle = data[pos:lib_end].decode(ENCODING, errors="replace").strip()
        except Exception:
            libelle = data[pos:lib_end].decode("latin-1", errors="replace").strip()
        pos = lib_end

        # Blocs 11001 : collecter tous les (tarif, date_debut, date_fin), puis garder le dernier par date de validité
        tariff_blocks: list[dict] = []
        while pos < size - 20:
            if data[pos : pos + 5] == b"11001":
                block = data[pos : pos + 100]
                tarif = extract_tarif_from_block(block)
                d1, d2 = extract_dates_from_block(block)
                if tarif is not None or d1 or d2:
                    tariff_blocks.append({"tarif": tarif, "date_debut": d1, "date_fin": d2})
                pos += 100
            elif re.match(rb"^\d{10,11}\s", data[pos : pos + 15]):
                break
            else:
                pos += 1

        prix_unitaire_reglemente = 0.0
        last_tarif = None
        last_date_debut = None
        last_date_fin = None
        if tariff_blocks:
            def _key(b: dict) -> tuple:
                fin = b.get("date_fin") or ""
                deb = b.get("date_debut") or ""
                def parse_jm(a: str) -> tuple:
                    if not a or len(a) != 10:
                        return (0, 0, 0)
                    p = a.split("/")
                    if len(p) != 3:
                        return (0, 0, 0)
                    try:
                        return (int(p[2]), int(p[1]), int(p[0]))
                    except ValueError:
                        return (0, 0, 0)
                return (parse_jm(fin), parse_jm(deb))
            best = max(tariff_blocks, key=_key)
            last_tarif = best.get("tarif")
            last_date_debut = best.get("date_debut")
            last_date_fin = best.get("date_fin")

        results[code_lpp] = {
            "code_lpp": code_lpp,
            "libelle": libelle,
            "tarif": last_tarif,
            "prix_unitaire_reglemente": prix_unitaire_reglemente,
            "date_debut_validite": last_date_debut,
            "date_fin_validite": last_date_fin,
        }

    return list(results.values())


def main() -> None:
    ap = argparse.ArgumentParser(description="Extraction LPP DBF → CSV pour Sheets")
    ap.add_argument("input", nargs="?", help="Fichier LPPTOT (.zip, .dbf ou fichier extrait)")
    ap.add_argument("--url", action="store_true", help="Télécharger depuis l'URL LPPTOT867 au lieu d'un fichier local")
    ap.add_argument("--output", "-o", default="lpp_sheets.csv", help="Fichier CSV de sortie")
    ap.add_argument("--encoding", default=ENCODING, help="Encodage du fichier source")
    args = ap.parse_args()

    if args.url:
        data = fetch_lpp_from_url()
    elif args.input:
        data = read_lpp_file(args.input)
    else:
        ap.error("Indiquez un fichier ou --url pour télécharger depuis l'URL LPPTOT867")
    records = parse_records(data)
    if not records:
        records = parse_records_v2(data)

    outpath = Path(args.output)
    outpath.parent.mkdir(parents=True, exist_ok=True)
    with open(outpath, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter=";")
        w.writerow(["Code LPP", "Libellé", "Tarif", "Prix unitaire réglementé", "Date début validité", "Date fin validité"])
        for r in records:
            w.writerow([
                r["code_lpp"],
                r["libelle"],
                r["tarif"] if r["tarif"] is not None else "",
                r["prix_unitaire_reglemente"],
                r["date_debut_validite"] or "",
                r["date_fin_validite"] or "",
            ])
    print(f"Exporté {len(records)} lignes vers {outpath}")


if __name__ == "__main__":
    main()
