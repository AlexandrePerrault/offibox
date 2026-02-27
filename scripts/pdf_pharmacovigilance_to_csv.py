#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Extrait la liste des centres régionaux de pharmacovigilance depuis un PDF ANSM
et génère un CSV : nom, adresse complète, tel, fax, mail.

Usage:
  python pdf_pharmacovigilance_to_csv.py [chemin.pdf]
  Par défaut: C:\\Users\\perra\\Downloads\\liste-des-centres-regionaux-de-pharmacovigilance (1).pdf

Dépendance: pip install pdfplumber
"""
from __future__ import annotations

import csv
import re
import sys
from pathlib import Path

try:
    import pdfplumber
except ImportError:
    print("Installation requise: pip install pdfplumber")
    sys.exit(1)

# Chemin par défaut
DEFAULT_PDF = Path(r"C:\Users\perra\Downloads\liste-des-centres-regionaux-de-pharmacovigilance (1).pdf")

# Regex pour extraire les champs
RE_TEL = re.compile(
    r"(?:Tél(?:éphone)?\.?\s*[:]\s*)?(0[1-9](?:[\s.]?\d{2}){4})",
    re.IGNORECASE,
)
RE_FAX = re.compile(
    r"Fax\s*[:]\s*(0[1-9](?:[\s.]?\d{2}){4})",
    re.IGNORECASE,
)
RE_MAIL = re.compile(
    r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}",
)
# Adresse : souvent plusieurs lignes, chiffres + rue/av/bd/bp/cedex
RE_LIGNE_ADRESSE = re.compile(
    r"^\d{1,3},?\s*(?:rue|av\.?|avenue|bd\.?|boulevard|place|allée|cours|quai)\b|"
    r"^\s*BP\s*\d+|"
    r"^\d{5}\s+[A-Za-zÀ-ÿ\-'\s]+(?:cedex)?\s*\d*$|"
    r"^[A-Za-zÀ-ÿ\-'\s]+\s+\d{5}\s+",
    re.IGNORECASE,
)


def normalize_phone(s: str) -> str:
    """Garde uniquement les chiffres d'un numéro (pour uniformiser)."""
    digits = re.sub(r"\D", "", s)
    if len(digits) == 10 and digits.startswith("0"):
        return f"{digits[:2]} {digits[2:4]} {digits[4:6]} {digits[6:8]} {digits[8:10]}"
    return s.strip()


def extract_from_text(pdf_path: Path) -> list[dict]:
    """Extrait les centres depuis le texte du PDF (structure ANSM : Centre d'X / Centre de X)."""
    rows: list[dict] = []
    with pdfplumber.open(pdf_path) as pdf:
        full_text = ""
        for page in pdf.pages:
            full_text += page.extract_text() or ""
            full_text += "\n"

    # Découper par "Centre d'X" ou "Centre de X" (apostrophe typo ou ASCII)
    blocks = re.split(
        r"(?=\bCentre\s+d[''\u2019]\w+|\bCentre\s+de\s+\w+)",
        full_text,
        flags=re.IGNORECASE,
    )

    for raw in blocks:
        raw = raw.strip()
        if not raw or len(raw) < 10:
            continue

        lines = [ln.strip() for ln in raw.splitlines() if ln.strip()]
        if not lines:
            continue

        nom = lines[0]
        if "Centre d" not in nom and "Centre de " not in nom:
            continue

        tel = ""
        fax = ""
        mail = ""
        adresse_lines: list[str] = []

        for line in lines[1:]:
            # Téléphone (principal)
            if re.match(r"Téléphone\s*:\s*", line, re.I):
                m = re.search(r"0[1-9](?:[\s.]?\d{2}){4}", line)
                if m and not tel:
                    tel = normalize_phone(m.group(0))
                continue
            if re.match(r"Télécopie\s*:\s*", line, re.I):
                m = re.search(r"0[1-9](?:[\s.]?\d{2}){4}", line)
                if m and not fax:
                    fax = normalize_phone(m.group(0))
                continue
            if re.match(r"e-mail\s*:\s*", line, re.I):
                m = RE_MAIL.search(line)
                if m and not mail:
                    mail = m.group(0)
                continue
            # Ignorer lignes de mise en forme
            if any(
                line.startswith(x)
                for x in (
                    "Départements concernés",
                    "Acceder au site",
                    "Secrétariat de",
                    "Site Internet",
                )
            ):
                continue
            if re.match(r"^[A-Za-z\-]+\s*\(\d{2}\)\s*$", line):  # Aisne (02)
                continue
            # Responsable : Mme/M./Dr ... (on ne met pas dans l'adresse)
            if re.match(r"^(?:Mme?\.?|Dr)\s+", line, re.I) and "Téléphone" not in line:
                continue
            if line == "Centre Régional de Pharmacovigilance":
                continue
            # Ligne d'adresse : CHU/CHRU/Hôpital, ou numéro + voie, ou CP + ville
            if (
                re.match(r"^(?:CHU|CHRU|Hôpital|Hôpitaux)\b", line, re.I)
                or re.match(r"^\d{1,3},?\s*(?:rue|av|bd|place|boulevard|allée|cours|quai)\b", line, re.I)
                or re.match(r"^\s*BP\s*\d+", line, re.I)
                or re.match(r"^\d{5}\s+[A-Za-zÀ-ÿ\-'\s]+(?:cedex)?\s*\d*$", line, re.I)
                or re.match(r"^Bâtiment\s", line, re.I)
                or (len(line) > 3 and not line.startswith("http") and "@" not in line)
            ):
                adresse_lines.append(line)
                continue
            # Autres lignes courtes (ex: "Bâtiment gris") → adresse
            if len(line) < 50 and "Téléphone" not in line and "Télécopie" not in line:
                adresse_lines.append(line)

        adresse = " ".join(adresse_lines).strip()
        # Nettoyer adresse : garder une seule ligne si tout est collé
        if "\n" not in adresse and len(adresse) > 100:
            adresse = adresse[:200] + "…" if len(adresse) > 200 else adresse

        rows.append({
            "nom": nom,
            "adresse_complete": adresse,
            "tel": tel,
            "fax": fax,
            "mail": mail,
        })

    return rows


def extract_from_tables(pdf_path: Path) -> list[dict] | None:
    """Tente d'extraire via les tableaux détectés par pdfplumber."""
    rows: list[dict] = []
    with pdfplumber.open(pdf_path) as pdf:
        for page in pdf.pages:
            tables = page.extract_tables()
            for table in tables or []:
                if not table or len(table) < 2:
                    continue
                header = [str(c or "").strip().lower() for c in table[0]]
                # Chercher colonnes utiles
                idx_nom = idx_addr = idx_tel = idx_fax = idx_mail = -1
                for i, h in enumerate(header):
                    if "nom" in h or "centre" in h or "ville" in h:
                        idx_nom = i
                    if "adresse" in h or "adresse" in h:
                        idx_addr = i
                    if "tél" in h or "tel" in h or "téléphone" in h:
                        idx_tel = i
                    if "fax" in h:
                        idx_fax = i
                    if "mail" in h or "mél" in h or "courriel" in h or "email" in h:
                        idx_mail = i
                for r in table[1:]:
                    cells = [str(c or "").strip() for c in r]
                    if not any(cells):
                        continue
                    nom = cells[idx_nom] if 0 <= idx_nom < len(cells) else (cells[0] if cells else "")
                    adresse = cells[idx_addr] if 0 <= idx_addr < len(cells) else ""
                    tel = cells[idx_tel] if 0 <= idx_tel < len(cells) else ""
                    fax = cells[idx_fax] if 0 <= idx_fax < len(cells) else ""
                    mail = cells[idx_mail] if 0 <= idx_mail < len(cells) else ""
                    if nom or adresse or tel or mail:
                        rows.append({
                            "nom": nom,
                            "adresse_complete": adresse,
                            "tel": tel,
                            "fax": fax,
                            "mail": mail,
                        })
    return rows if rows else None


def main() -> None:
    if len(sys.argv) >= 2:
        pdf_path = Path(sys.argv[1])
    else:
        pdf_path = DEFAULT_PDF

    if not pdf_path.exists():
        print(f"Fichier introuvable: {pdf_path}")
        sys.exit(1)

    out_path = pdf_path.with_suffix(".csv")
    print(f"Lecture: {pdf_path}")
    print(f"Sortie:  {out_path}")

    # Essayer d'abord le texte (structure ANSM "Centre d'X / Centre de X")
    rows = extract_from_text(pdf_path)
    if not rows or (len(rows) < 5 and extract_from_tables(pdf_path)):
        table_rows = extract_from_tables(pdf_path)
        if table_rows and len(table_rows) > len(rows or []):
            rows = table_rows

    if not rows:
        print("Aucune donnée extraite. Vérifiez le format du PDF.")
        sys.exit(1)

    with open(out_path, "w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(
            f,
            fieldnames=["nom", "adresse_complete", "tel", "fax", "mail"],
            delimiter=";",
        )
        w.writeheader()
        w.writerows(rows)

    print(f"OK: {len(rows)} centre(s) écrit(s) dans {out_path}")


if __name__ == "__main__":
    main()
