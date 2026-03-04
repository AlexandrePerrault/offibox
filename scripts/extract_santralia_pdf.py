#!/usr/bin/env python3
"""
Extrait les codes (7 ou 13 chiffres) et libellés du catalogue Santralia PDF
à partir de la page 5, et écrit un CSV : Code (A), Nom du produit (B),
URL du laboratoire (C), URL du logo (D).

Les URL catalogue et logos viennent de santralia_catalogue_urls.json
(liste d'objets avec name, path, url ; catalogue = PDF par labo, logos = LOGOS PARTENAIRES).
La correspondance produit <-> labo se fait par le nom du laboratoire (ex. Théa).

Usage:
  python scripts/extract_santralia_pdf.py
  python scripts/extract_santralia_pdf.py -o export.csv
  python scripts/extract_santralia_pdf.py --urls-json firebase-export/santralia_catalogue_urls.json
  python scripts/extract_santralia_pdf.py --firebase-credentials serviceAccountKey.json

Nécessite: pip install pymupdf
Optionnel (pour les URL Firebase): pip install firebase-admin
"""

import argparse
import csv
import datetime
import json
import re
import sys
import unicodedata
from pathlib import Path

try:
    import fitz  # pymupdf
except ImportError:
    print("Erreur: installez pymupdf avec: python -m pip install pymupdf", file=sys.stderr)
    sys.exit(1)

try:
    import firebase_admin
    from firebase_admin import credentials, storage
    _FIREBASE_AVAILABLE = True
except ImportError:
    _FIREBASE_AVAILABLE = False

FIREBASE_STORAGE_PREFIX = "SANTRALIA-CATALOGUE 2025"
FIREBASE_BUCKET = "offibox-prod.firebasestorage.app"
LOGOS_PARTENAIRES = "LOGOS PARTENAIRES"

FIRST_PAGE_INDEX = 4
RE_CODE_13 = re.compile(r"\b(\d{13})\b")
RE_CODE_7 = re.compile(r"\b(\d{7})\b")

DEFAULT_PDF_PATH = r"C:\Users\perra\OneDrive\Desktop\santralia\CATALOGUE Santralia avril 2025 (1).pdf"
DEFAULT_URLS_JSON = "firebase-export/santralia_catalogue_urls.json"


def normalize_lab(s: str) -> str:
    """Normalise le nom du labo pour la correspondance (ex. Théa -> THEA, BAYER -> BAYER)."""
    s = (s or "").strip().upper()
    if not s:
        return ""
    nfd = unicodedata.normalize("NFD", s)
    return "".join(c for c in nfd if unicodedata.category(c) != "Mn")


def load_santralia_catalogue_urls(json_path: str) -> tuple[dict[str, str], dict[str, str]]:
    """
    Charge santralia_catalogue_urls.json (liste d'objets {name, path, url}).
    Retourne (url_by_lab, logo_by_lab) avec clés normalisées (nom labo).
    - Catalogue : path du type "SANTRALIA-CATALOGUE 2025/BAYER.pdf" -> URL du PDF labo.
    - Logos : path contenant "LOGOS PARTENAIRES" -> URL du logo (nom = nom du labo, ex. Théa.png).
    """
    with open(json_path, encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, list):
        raise ValueError("santralia_catalogue_urls.json doit être une liste d'objets {name, path, url}")
    url_by_lab: dict[str, str] = {}
    logo_by_lab: dict[str, str] = {}
    logo_name_len: dict[str, int] = {}
    for item in data:
        if not isinstance(item, dict):
            continue
        path = (item.get("path") or "").strip()
        url = (item.get("url") or "").strip()
        name = (item.get("name") or "").strip()
        if not path or not url:
            continue
        is_logo = LOGOS_PARTENAIRES.upper() in path.upper()
        if is_logo:
            # Nom du fichier sans extension = nom du labo (ex. Théa.png -> Théa)
            base = name
            matched_ext = ""
            for ext in (".png", ".jpg", ".jpeg", ".svg", ".webp", ".gif", ".pdf"):
                if base.upper().endswith(ext.upper()):
                    matched_ext = ext.lower()
                    base = base[: -len(ext)]
                    break
            # On ne veut que des logos "image" (pas de PDF dans la colonne logo)
            if matched_ext == ".pdf":
                continue
            # Ignorer noms avec id/suffix (ex. Bayer_idmJvu77_g_0.svg) si on a déjà un logo simple
            key = normalize_lab(base)
            if not key:
                continue
            # Préférer les noms simples (ex. Théa.png) aux noms avec id (ex. Bayer_idmJvu77_g_0.svg)
            prev_len = logo_name_len.get(key, 999)
            if key not in logo_by_lab or len(name) < prev_len:
                logo_by_lab[key] = url
                logo_name_len[key] = len(name)
        else:
            # Catalogue PDF : "SANTRALIA-CATALOGUE 2025/BAYER.pdf"
            if not path.upper().endswith(".PDF"):
                continue
            base = path.split("/")[-1].strip()
            if base.upper().endswith(".PDF"):
                base = base[:-4]
            key = normalize_lab(base)
            if key:
                url_by_lab[key] = url
    return url_by_lab, logo_by_lab


def extract_codes_and_libelles(
    pdf_path: str,
    known_labs: set[str] | None = None,
) -> list[tuple[str, str, str]]:
    """
    Extrait (code, libellé, nom_labo_normalisé) du PDF.
    Si known_labs est fourni, détecte les en-têtes de section (noms de labo) pour associer chaque code au labo courant.
    """
    doc = fitz.open(pdf_path)
    rows: list[tuple[str, str, str]] = []
    seen_codes: set[str] = set()
    known_labs = known_labs or set()
    current_lab = ""

    for page_num in range(FIRST_PAGE_INDEX, len(doc)):
        page = doc[page_num]
        text = page.get_text()
        lines = text.splitlines()

        for i, line in enumerate(lines):
            line = line.strip()
            if not line:
                continue

            if known_labs:
                line_key = normalize_lab(line)
                # Heuristique: on ne change de "labo courant" que si la ligne ressemble à un en-tête de section,
                # i.e. si elle est suivie d'une ligne contenant un CIP (début de liste produits).
                next_line = lines[i + 1].strip() if i + 1 < len(lines) else ""
                next_has_code = bool(RE_CODE_13.search(next_line) or RE_CODE_7.search(next_line))

                if line_key in known_labs and next_has_code:
                    current_lab = line_key
                    continue

                if next_has_code and (not RE_CODE_13.search(line) and not RE_CODE_7.search(line)):
                    for lab in known_labs:
                        # Éviter les faux positifs avec des labos très courts (ex. "3") ou purement numériques.
                        if lab.isdigit() or len(lab) <= 2:
                            continue
                        if lab in line_key or line_key in lab:
                            current_lab = lab
                            break

            code = None
            m13 = RE_CODE_13.search(line)
            m7 = RE_CODE_7.search(line)
            if m13:
                code = m13.group(1)
            elif m7:
                code = m7.group(1)

            if not code or code in seen_codes:
                continue
            seen_codes.add(code)

            idx = line.find(code)
            if idx >= 0:
                libelle = line[idx + len(code):].strip()
            else:
                libelle = ""
            if not libelle and i + 1 < len(lines):
                libelle = lines[i + 1].strip()
            libelle = " ".join((libelle or "").split())

            rows.append((code, libelle, current_lab))

    doc.close()
    return rows


def _codes_in_string(s: str) -> set[str]:
    out: set[str] = set()
    for m in RE_CODE_13.finditer(s):
        out.add(m.group(1))
    for m in RE_CODE_7.finditer(s):
        out.add(m.group(1))
    return out


def fetch_firebase_urls_by_code(credentials_path: str) -> tuple[dict[str, str], str]:
    """Liste Firebase Storage SANTRALIA-CATALOGUE 2025, retourne code -> URL et une URL par défaut."""
    if not _FIREBASE_AVAILABLE:
        raise RuntimeError("firebase-admin requis: python -m pip install firebase-admin")
    cred = credentials.Certificate(credentials_path)
    try:
        firebase_admin.get_app()
    except ValueError:
        firebase_admin.initialize_app(cred, {"storageBucket": FIREBASE_BUCKET})
    bucket = storage.bucket()
    prefix = FIREBASE_STORAGE_PREFIX + "/"
    url_by_code: dict[str, str] = {}
    default_url = ""
    expiration = datetime.timedelta(days=7)
    for blob in bucket.list_blobs(prefix=prefix):
        name = blob.name
        codes = _codes_in_string(name)
        try:
            signed_url = blob.generate_signed_url(version="v4", expiration=expiration, method="GET")
        except Exception:
            from urllib.parse import quote
            encoded = quote(name, safe="")
            signed_url = f"https://firebasestorage.googleapis.com/v0/b/{FIREBASE_BUCKET}/o/{encoded}?alt=media"
        if not default_url and name.lower().endswith(".pdf"):
            default_url = signed_url
        for code in codes:
            url_by_code[code] = signed_url
    return url_by_code, default_url


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Extrait codes et libellés du catalogue Santralia (PDF, à partir de la page 5). CSV: Code, Nom, URL catalogue, URL logo."
    )
    parser.add_argument(
        "pdf",
        type=str,
        nargs="?",
        default=DEFAULT_PDF_PATH,
        help="Chemin vers le PDF",
    )
    parser.add_argument(
        "-o", "--output",
        type=str,
        default="santralia_catalogue_export.csv",
        help="Fichier CSV de sortie",
    )
    parser.add_argument(
        "--url",
        type=str,
        default="",
        help="URL par défaut (catalogue) si pas de correspondance",
    )
    parser.add_argument(
        "--urls-json",
        type=str,
        default="",
        help="Chemin vers santralia_catalogue_urls.json. Défaut: firebase-export/santralia_catalogue_urls.json",
    )
    parser.add_argument(
        "--firebase-credentials",
        type=str,
        default="",
        help="Chemin vers le JSON du compte de service Firebase (remplit URL catalogue par code)",
    )
    parser.add_argument(
        "--show-lab",
        action="store_true",
        help="Ajouter une colonne Laboratoire (nom du labo) pour vérifier la correspondance",
    )
    args = parser.parse_args()

    pdf_path = Path(args.pdf)
    if not pdf_path.is_file():
        print(f"Erreur: fichier introuvable: {pdf_path}", file=sys.stderr)
        sys.exit(1)

    url_by_lab: dict[str, str] = {}
    logo_by_lab: dict[str, str] = {}
    url_by_code: dict[str, str] = {}
    default_url = args.url or ""

    urls_json = args.urls_json or DEFAULT_URLS_JSON
    urls_json_path = Path(urls_json)
    if urls_json_path.is_file():
        print(f"Chargement des URL depuis {urls_json_path}...", file=sys.stderr)
        try:
            url_by_lab, logo_by_lab = load_santralia_catalogue_urls(str(urls_json_path))
            print(f"  {len(url_by_lab)} catalogues labo, {len(logo_by_lab)} logos.", file=sys.stderr)
        except Exception as e:
            print(f"Erreur santralia_catalogue_urls.json: {e}", file=sys.stderr)
            sys.exit(1)
    elif args.urls_json:
        print(f"Erreur: fichier introuvable: {urls_json_path}", file=sys.stderr)
        sys.exit(1)

    known_labs = set(url_by_lab.keys()) | set(logo_by_lab.keys())
    rows = extract_codes_and_libelles(str(pdf_path), known_labs=known_labs if known_labs else None)

    if args.firebase_credentials:
        cred_path = Path(args.firebase_credentials)
        if not cred_path.is_file():
            print(f"Erreur: fichier credentials introuvable: {cred_path}", file=sys.stderr)
            sys.exit(1)
        print("Récupération des URL depuis Firebase Storage...", file=sys.stderr)
        try:
            url_by_code, default_url = fetch_firebase_urls_by_code(str(cred_path))
            print(f"  {len(url_by_code)} codes associés à un fichier.", file=sys.stderr)
        except Exception as e:
            print(f"Erreur Firebase: {e}", file=sys.stderr)
            sys.exit(1)

    out_path = Path(args.output)
    with open(out_path, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.writer(f, delimiter=";", quoting=csv.QUOTE_MINIMAL)
        # Col 1 = Code CIP (7 ou 13 chiffres), Col 2 = Libellé, Col 3 = URL PDF labo Firebase, Col 4 = URL logo Firebase
        writer.writerow(["Code", "Libellé", "URL fichier labo Firebase", "URL logo Firebase"])
        for code, libelle, lab_key in rows:
            url_lab = url_by_lab.get(lab_key, default_url) if lab_key else default_url
            if url_by_code:
                url_lab = url_by_code.get(code, url_lab)
            logo_url = logo_by_lab.get(lab_key, "") if lab_key else ""
            writer.writerow([code, libelle, url_lab, logo_url])

    # Console Windows: éviter certains caractères Unicode (ex. "→")
    print(f"Export terminé: {len(rows)} lignes -> {out_path}")


if __name__ == "__main__":
    main()
