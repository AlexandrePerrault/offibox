#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Extrait du catalogue PDF Santralia un fichier PDF par laboratoire.
- Page 3 du PDF = sommaire (recapitulatif) : colonne 1 = nom labo, colonne 2 = pages a fusionner.
- Sortie : dossier SANTRALIA dans le dossier offibox CERP (a la racine du projet offibox).

Usage:
  python scripts/santralia_split_catalogue_by_lab.py [chemin_catalogue.pdf]
  python scripts/santralia_split_catalogue_by_lab.py --debug   # affiche le contenu de la page 3

Defaut: C:\\Users\\perra\\OneDrive\\Desktop\\santralia\\CATALOGUE Santralia avril 2025 (1).pdf

Dependances: pip install pdfplumber pypdf
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

try:
    import pdfplumber
except ImportError:
    print("pip install pdfplumber")
    sys.exit(1)
try:
    from pypdf import PdfReader, PdfWriter
except ImportError:
    print("pip install pypdf")
    sys.exit(1)

DEFAULT_PDF = Path(r"C:\Users\perra\OneDrive\Desktop\santralia\CATALOGUE Santralia avril 2025 (1).pdf")
SOMMAIRE_PAGE_INDEX = 2

def get_output_dir() -> Path:
    return Path(__file__).resolve().parent.parent / "offibox CERP" / "SANTRALIA"

def parse_page_range(s: str) -> list[int]:
    if not s or not str(s).strip():
        return []
    s = re.sub(r"\s+", " ", str(s).strip())
    out = []
    for part in re.split(r"[,;]", s):
        part = part.strip()
        if not part:
            continue
        m = re.match(r"^(\d+)\s*-\s*(\d+)$", part)
        if m:
            a, b = int(m.group(1)), int(m.group(2))
            for p in range(min(a, b), max(a, b) + 1):
                out.append(p - 1)
        else:
            try:
                out.append(int(part) - 1)
            except ValueError:
                continue
    return sorted(set(out))

def sanitize_filename(name: str) -> str:
    name = re.sub(r'[<>:"/\\|?*]', "_", name)
    return (re.sub(r"\s+", " ", name).strip() or "laboratoire")[:200]

def extract_table_from_sommaire(pdf_path: Path, debug: bool = False) -> list[tuple[str, list[int]]]:
    with pdfplumber.open(pdf_path) as pdf:
        if len(pdf.pages) <= SOMMAIRE_PAGE_INDEX:
            raise SystemExit("PDF trop court pour page 3.")
        page = pdf.pages[SOMMAIRE_PAGE_INDEX]
        text = page.extract_text() or ""
        if debug:
            print("--- Texte page 3 (extrait) ---")
            print(text[:2000] if text else "(vide)")
        # Parser le texte en priorité (format "LAB 4" ou "LAB 7 - 13")
        rows = _fallback_parse(text)
        if rows:
            return rows
        # Secours: tables
        tables = page.extract_tables()
        if not tables:
            return []
        table = max(tables, key=lambda t: len(t) if t else 0)
        if not table:
            return []
        for row in table:
            if not row or len(row) < 2:
                continue
            lab = (row[0] or "").strip()
            pages_str = (row[1] or "").strip()
            if len(row) >= 3 and not re.search(r"\d", pages_str) and re.search(r"\d", (row[2] or "")):
                lab = (row[1] or "").strip()
                pages_str = (row[2] or "").strip()
            if not lab or not pages_str or re.match(r"^(page|pages|n°)", lab, re.I):
                continue
            idx = parse_page_range(pages_str)
            if idx:
                rows.append((lab, idx))
        return rows

def _fallback_parse(text: str) -> list[tuple[str, list[int]]]:
    """Parse le recapitulatif: lignes 'LAB 4' ou 'LAB 7 - 13' puis optionnel 'x ...'."""
    rows = []
    # Lab name (majuscules/chiffres) puis espace puis page ou plage (N ou N - N)
    pattern = re.compile(r"^([A-Z0-9][A-Z0-9\s&\-'.]*?)\s+(\d+(?:\s*-\s*\d+)?)\s*")
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("Offre") or "valable jusqu" in line or "Récapitulatif" in line:
            continue
        if line.startswith("PARTENAIRES") or line.startswith("PAGE") or "Cliquez" in line:
            continue
        if re.match(r"^-?\s*\d+\s*-", line) or line == "-":
            continue
        m = pattern.match(line)
        if m:
            lab = m.group(1).strip()
            pages_str = m.group(2).strip()
            if not lab or re.match(r"^\d+$", lab):
                continue
            if (idx := parse_page_range(pages_str)) and len(lab) >= 2:
                rows.append((lab, idx))
            continue
        # Secours: fin de ligne = plage (ex. "LAB 7 - 13 x x")
        m2 = re.search(r"\s+(\d+(?:\s*-\s*\d+)?)\s+(?:x|$)", line)
        if m2:
            pages_str = m2.group(1).strip()
            lab = line[: m2.start()].strip()
            if lab and (idx := parse_page_range(pages_str)):
                rows.append((lab, idx))
    return rows

def extract_pages_to_pdf(pdf_path: Path, indices: list[int], out_path: Path) -> None:
    reader = PdfReader(pdf_path)
    writer = PdfWriter()
    for i in indices:
        if 0 <= i < len(reader.pages):
            writer.add_page(reader.pages[i])
    with open(out_path, "wb") as f:
        writer.write(f)

def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    debug = "--debug" in sys.argv
    pdf_path = Path(args[0] if args else DEFAULT_PDF)
    if not pdf_path.is_file():
        print("Fichier introuvable:", pdf_path)
        sys.exit(1)
    out_dir = get_output_dir()
    out_dir.mkdir(parents=True, exist_ok=True)
    print("Catalogue:", pdf_path)
    print("Sortie:", out_dir)
    try:
        rows = extract_table_from_sommaire(pdf_path, debug=debug)
    except Exception as e:
        print("Erreur sommaire:", e)
        sys.exit(1)
    if not rows:
        print("Aucune ligne labo/pages sur la page 3. Lancez avec --debug pour afficher le contenu extrait.")
        sys.exit(1)
    print("Laboratoires:", len(rows))
    for lab_name, indices in rows:
        safe = sanitize_filename(lab_name)
        out_path = out_dir / f"{safe}.pdf"
        try:
            extract_pages_to_pdf(pdf_path, indices, out_path)
            print(" ->", out_path.name, "(" + str(len(indices)) + " p.)")
        except Exception as e:
            print(" ERREUR", safe, e)
    print("Termine.")

if __name__ == "__main__":
    main()
