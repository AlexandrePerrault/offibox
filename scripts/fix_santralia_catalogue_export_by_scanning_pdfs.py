#!/usr/bin/env python3
"""
Répare un export CSV Santralia en remplissant les colonnes URL par correspondance CIP -> PDF labo.

Principe (robuste même si le gros PDF est en colonnes) :
1) Charger `firebase-export/santralia_catalogue_urls.json` (URLs Firebase avec token)
2) Pour chaque PDF labo, télécharger le PDF et extraire tous les CIP (7/13 chiffres) qu'il contient
3) Construire un mapping CIP -> (labo_key, pdf_url)
4) Réécrire le CSV : Col1=CIP, Col2=Libellé, Col3=URL PDF labo, Col4=URL logo (image) du même labo

Usage:
  python scripts/fix_santralia_catalogue_export_by_scanning_pdfs.py ^
    --input "C:\\Users\\perra\\Downloads\\CERP 2026+++ - santralia_catalogue_export.csv" ^
    --urls-json "C:\\Users\\perra\\Documents\\projets_flutter\\offibox\\firebase-export\\santralia_catalogue_urls.json" ^
    --output "C:\\Users\\perra\\Downloads\\santralia_catalogue_export_repaired.csv"

Pré-requis:
  pip install pymupdf
"""

import argparse
import csv
import json
import re
import sys
import unicodedata
import urllib.request
from pathlib import Path

try:
    import fitz  # pymupdf
except ImportError:
    print("Erreur: installez pymupdf avec: python -m pip install pymupdf", file=sys.stderr)
    raise SystemExit(1)


RE_CODE_13 = re.compile(r"\b(\d{13})\b")
RE_CODE_7 = re.compile(r"\b(\d{7})\b")


def normalize_lab(s: str) -> str:
    s = (s or "").strip().upper()
    if not s:
        return ""
    nfd = unicodedata.normalize("NFD", s)
    s = "".join(c for c in nfd if unicodedata.category(c) != "Mn")
    s = re.sub(r"[^A-Z0-9 ]+", " ", s)
    return " ".join(s.split())


def extract_codes_from_text(text: str) -> set[str]:
    out: set[str] = set()
    out.update(RE_CODE_13.findall(text))
    out.update(RE_CODE_7.findall(text))
    return out


def sniff_delimiter(sample: str) -> str:
    # fichier Excel FR parfois en ";" ; l'exemple fourni est en ","
    candidates = [",", ";", "\t"]
    best = ","
    best_count = -1
    for d in candidates:
        c = sample.count(d)
        if c > best_count:
            best = d
            best_count = c
    return best


def load_urls_json(json_path: str, prefix: str) -> tuple[dict[str, str], dict[str, str]]:
    """
    Retourne:
      - lab_pdf_by_labkey: LABKEY -> url PDF
      - logo_by_labkey: LABKEY -> url logo (image)
    """
    data = json.load(open(json_path, "r", encoding="utf-8"))
    if not isinstance(data, list):
        raise ValueError("urls-json doit être une liste")

    prefix = prefix.rstrip("/") + "/"
    logos_marker = f"{prefix}LOGOS PARTENAIRES/".upper()
    lab_pdf_by_labkey: dict[str, str] = {}

    # logos: préférer le nom le plus court (souvent le plus 'propre')
    logo_by_labkey: dict[str, str] = {}
    logo_name_len: dict[str, int] = {}

    for it in data:
        if not isinstance(it, dict):
            continue
        path = str(it.get("path") or "").strip()
        url = str(it.get("url") or "").strip()
        name = str(it.get("name") or "").strip()
        if not path or not url:
            continue
        if not path.startswith(prefix):
            continue

        upper_path = path.upper()
        if logos_marker in upper_path:
            # Logo: seulement image (pas PDF)
            base = name
            matched_ext = ""
            for ext in (".png", ".jpg", ".jpeg", ".svg", ".webp", ".gif", ".pdf"):
                if base.upper().endswith(ext.upper()):
                    matched_ext = ext.lower()
                    base = base[: -len(ext)]
                    break
            if matched_ext == ".pdf" or not matched_ext:
                continue
            base = base.replace("_", " ")
            base = re.split(r"(\\bID\\b|\\bLOGO\\b)", base, maxsplit=1, flags=re.IGNORECASE)[0].strip()
            key = normalize_lab(base)
            if not key:
                continue
            prev = logo_name_len.get(key, 999)
            if key not in logo_by_labkey or len(name) < prev:
                logo_by_labkey[key] = url
                logo_name_len[key] = len(name)
        else:
            # PDF labo
            if not upper_path.endswith(".PDF"):
                continue
            filename = path.split("/")[-1]
            lab = filename[:-4]
            key = normalize_lab(lab)
            if key:
                lab_pdf_by_labkey[key] = url

    return lab_pdf_by_labkey, logo_by_labkey


def build_code_to_lab_mapping(lab_pdf_by_labkey: dict[str, str], timeout_s: int) -> tuple[dict[str, str], dict[str, str]]:
    """
    Retourne:
      - code_to_labkey: CIP -> LABKEY
      - labkey_to_pdfurl: LABKEY -> pdf_url (identique entrée)
    """
    code_to_labkey: dict[str, str] = {}
    # Inverser pour itérer
    for labkey, pdf_url in lab_pdf_by_labkey.items():
        try:
            pdf_bytes = urllib.request.urlopen(pdf_url, timeout=timeout_s).read()
        except Exception as e:
            print(f"[WARN] téléchargement impossible {labkey}: {e}", file=sys.stderr)
            continue
        try:
            doc = fitz.open(stream=pdf_bytes, filetype="pdf")
        except Exception as e:
            print(f"[WARN] PDF illisible {labkey}: {e}", file=sys.stderr)
            continue

        try:
            codes: set[str] = set()
            for p in range(len(doc)):
                codes |= extract_codes_from_text(doc[p].get_text())
            for c in codes:
                prev = code_to_labkey.get(c)
                if prev and prev != labkey:
                    # collision : garder le premier, mais log
                    print(f"[WARN] CIP {c} présent dans {prev} et {labkey}", file=sys.stderr)
                    continue
                code_to_labkey[c] = labkey
        finally:
            doc.close()

    return code_to_labkey, lab_pdf_by_labkey


def main() -> None:
    ap = argparse.ArgumentParser(description="Répare un CSV Santralia en remplissant les URLs par correspondance CIP -> PDF labo.")
    ap.add_argument("--input", "-i", required=True, help="CSV d'entrée (CIP en col 1, libellé en col 2)")
    ap.add_argument("--urls-json", required=True, help="firebase-export/santralia_catalogue_urls.json (URLs Firebase avec token)")
    ap.add_argument("--output", "-o", required=True, help="CSV de sortie")
    ap.add_argument("--prefix", default="SANTRALIA-CATALOGUE 2025", help="Préfixe dossier dans le JSON")
    ap.add_argument("--timeout", type=int, default=30, help="Timeout téléchargement PDF (secondes)")
    ap.add_argument("--delimiter", default="", help="Forcer séparateur CSV de sortie (défaut: même que l'entrée)")
    args = ap.parse_args()

    in_path = Path(args.input)
    if not in_path.is_file():
        print(f"Erreur: fichier introuvable: {in_path}", file=sys.stderr)
        raise SystemExit(1)
    urls_path = Path(args.urls_json)
    if not urls_path.is_file():
        print(f"Erreur: fichier introuvable: {urls_path}", file=sys.stderr)
        raise SystemExit(1)

    lab_pdf_by_labkey, logo_by_labkey = load_urls_json(str(urls_path), args.prefix)
    print(f"URLs JSON: {len(lab_pdf_by_labkey)} PDFs labo, {len(logo_by_labkey)} logos image", file=sys.stderr)

    code_to_labkey, _ = build_code_to_lab_mapping(lab_pdf_by_labkey, timeout_s=args.timeout)
    print(f"Mapping CIP -> labo: {len(code_to_labkey)} codes trouvés dans les PDFs labo", file=sys.stderr)

    # Lire un échantillon pour détecter le séparateur d'entrée
    sample = in_path.read_text(encoding="utf-8-sig", errors="replace")[:4096]
    in_delim = sniff_delimiter(sample)
    out_delim = args.delimiter if args.delimiter else in_delim

    out_path = Path(args.output)
    filled = 0
    total = 0

    with open(in_path, "r", encoding="utf-8-sig", newline="") as f_in, open(out_path, "w", encoding="utf-8-sig", newline="") as f_out:
        reader = csv.reader(f_in, delimiter=in_delim)
        writer = csv.writer(f_out, delimiter=out_delim, quoting=csv.QUOTE_MINIMAL)

        # Lire header si présent
        first = next(reader, None)
        if first is None:
            print("Erreur: CSV vide", file=sys.stderr)
            raise SystemExit(1)

        # On écrit toujours notre header standard
        writer.writerow(["Code", "Libellé", "URL laboratoire (PDF)", "URL logo (image)"])

        # Si la première ligne n'est pas un code, on l'ignore (header d'origine)
        def looks_like_code(x: str) -> bool:
            x = (x or "").strip()
            return bool(RE_CODE_13.fullmatch(x) or RE_CODE_7.fullmatch(x))

        if looks_like_code(first[0] if first else ""):
            rows_iter = [first] + list(reader)
        else:
            rows_iter = list(reader)

        for row in rows_iter:
            if not row:
                continue
            code = (row[0] if len(row) > 0 else "").strip()
            libelle = (row[1] if len(row) > 1 else "").strip()
            if not code:
                continue
            total += 1

            labkey = code_to_labkey.get(code, "")
            pdf_url = lab_pdf_by_labkey.get(labkey, "") if labkey else ""
            logo_url = logo_by_labkey.get(labkey, "") if labkey else ""

            if pdf_url or logo_url:
                filled += 1
            writer.writerow([code, libelle, pdf_url, logo_url])

    print(f"Terminé: {filled}/{total} lignes remplies -> {out_path}", file=sys.stderr)


if __name__ == "__main__":
    main()

