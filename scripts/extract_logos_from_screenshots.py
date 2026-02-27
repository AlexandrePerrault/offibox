#!/usr/bin/env python3
"""
Extrait les logos depuis les captures d'écran (grilles) et les enregistre dans assets/icons.
Usage: python scripts/extract_logos_from_screenshots.py

Dépendance: pip install Pillow
"""
import os
import re
import sys
import unicodedata

try:
    from PIL import Image
except ImportError:
    print("Installation requise: pip install Pillow")
    exit(1)

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
ASSETS_ICONS = os.path.join(PROJECT_ROOT, "assets", "icons")

# Dossier des captures: par défaut assets du projet; sinon 1er argument ou .cursor workspace
def _screenshots_dir():
    if len(sys.argv) > 1:
        return os.path.abspath(sys.argv[1])
    default = os.path.join(PROJECT_ROOT, "assets")
    if os.path.isdir(default):
        return default
    # Workspace Cursor parfois = parent ou autre
    for candidate in [os.path.join(os.path.dirname(PROJECT_ROOT), "assets"), default]:
        if os.path.isdir(candidate):
            return candidate
    return default

# Marge en pixels pour éviter les bords des cellules (icône i, coche verte)
CELL_PADDING = 8


def slug(name):
    """Convertit un nom en identifiant fichier: minuscules, alphanum + underscore."""
    if not name or not name.strip():
        return None
    s = name.strip()
    s = unicodedata.normalize("NFD", s)
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    s = re.sub(r"[^\w\s\-.]", " ", s)
    s = re.sub(r"\s+", "_", s).strip("_")
    s = s.lower()
    if not s:
        return None
    return s[:60]  # limite longueur


# (fichier relatif à assets/, cols, rows, liste des noms par cellule row par row, de gauche à droite)
SCREENS = [
    (
        "c__Users_perra_AppData_Roaming_Cursor_User_workspaceStorage_b44561d4537f5734313960b5c3f81a9d_images_image-66801103-9026-4783-833b-d52e74161cf1.png",
        6,
        7,
        [
            "DigiMail",
            "Abbvie",
            "ABM Pharma",
            "Aboca",
            "Alloga",
            "Arkopharma",
            "Arrow",
            "Bausch Lomb",
            "Bayer",
            "Biogaran Pro",
            "Boiron",
            "Boost",
            "Bruneau",
            "Bureau Vallée",
            "Caudalie",
            "CERP Bretagne Atlantique",
            "Colpropur",
            "CSP",
            "Delpech",
            "Demat'Box Extencia",
            "DomesPharma",
            "Edenred",
            "EDF Entreprises",
            "EffiNov",
            "Eurodep",
            "Havea",
            "Hydratis",
            "Ineldea",
            "Le Comptoir des Pharmacies",
            "Lehning",
            "Lifescan",
            "Ma Formation Officinale",
            "Market Pharm",
            "Mayoly Spindler",
            "Medidestock",
            "Même",
            "Viatris",
            "Cooper",
            "Nestlé Health Science",
            "Nutergia",
            "OCP+",
            "Opella.+",
        ],
    ),
    (
        "c__Users_perra_AppData_Roaming_Cursor_User_workspaceStorage_b44561d4537f5734313960b5c3f81a9d_images_image-23e46bbd-1ce6-42a5-aeb1-cff3f3a07793.png",
        6,
        4,
        [
            "Opérations Commerciales Bayer",
            "Orkyn",
            "Perrigo",
            "Pharmasmile",
            "Pharmedinsight",
            "Pharmedisound",
            "Pharmedistore",
            "Pierre Fabre",
            "Podowell",
            "Pranarom (Inula)",
            "Resopharma",
            "SACEM",
            "Sagitta Pharma",
            "Sanofi Pro",
            "Solocal",
            "Splayce",
            "SY by Cegedim",
            "Teva",
            "Thuasne",
            "UPSA",
            "Urgo",
            "Viatris (Mylan)",
            "Weleda",
        ],
    ),
    (
        "c__Users_perra_AppData_Roaming_Cursor_User_workspaceStorage_b44561d4537f5734313960b5c3f81a9d_images_image-0b2464cb-f27c-42e2-a4a3-219fea366a92.png",
        6,
        5,
        [
            "3M Science",
            "Afone",
            "Allergan",
            "Alliance",
            "Almadia",
            "Altapharm",
            "Amazon",
            "Amazon Business",
            "Ambapharm",
            "Amiem",
            "Amoena",
            "Amoena via Esker",
            "Apave",
            "Appel Medical",
            "Aprium",
            "Aquarelle Pro",
            "Aquitem",
            "Arrow Coopérations Commerciales",
            "Arval",
            "Assistance Pharma",
            "Avril",
            "Axeo",
            "Axonaut",
            "Biocyte",
            "BNP Paribas Leasing Solution",
            "Boticinal",
            "Boxtal",
            "Bureau Vallée Guyane",
            "Caduciel",
            "Cailleau",
        ],
    ),
    (
        "c__Users_perra_AppData_Roaming_Cursor_User_workspaceStorage_b44561d4537f5734313960b5c3f81a9d_images_image-df0d6842-bf7f-4ef2-9bbc-15150f0a0a6c.png",
        6,
        7,
        [
            "Calk",
            "Capitol Pharma via Zeendoc",
            "CERP Astera",
            "CERP GPG",
            "CERP RRM",
            "Cerp Sipr",
            "Chiesi",
            "Cizeta",
            "Cloud Eco",
            "Club Officine",
            "Coffre Integral Pharma",
            "Conciergerie Pharmavie",
            "Copharmay",
            "Cosmédiet Biotechnie",
            "CPO Plus",
            "CS Pharma via Esker",
            "Défimédoc",
            "Delpech Nancy",
            "Despharm",
            "Difarmed",
            "DirectLog",
            "Distripharm",
            "DLL",
            "Doctolib Pro",
            "Donjoy",
            "Dr. Hauschka",
            "Dynamiz Pharma",
            "EA Pharma",
            "Ededoc",
            "Ededoc bis",
            "EDF Guyane",
            "EDF Reunion",
            "ekWateur",
            "ekWateur Pro",
            "Elis",
            "Elixir Pharma",
            "EMAPO",
            "ONGIE",
            "EOLYS beauté",
            "EPSILON",
            "ESC Laboratoire",
            "Espace Monge",
        ],
    ),
    (
        "c__Users_perra_AppData_Roaming_Cursor_User_workspaceStorage_b44561d4537f5734313960b5c3f81a9d_images_image-ba4744e6-abc8-4c83-8f06-771926d75103.png",
        6,
        6,
        [
            "Estipharm",
            "Eucerin",
            "EvoluPharm",
            "Fidel Fillaud",
            "FLD via ESKER",
            "FLD via Zeendoc",
            "France Prep",
            "Free",
            "Free Pro",
            "Freestyle Libre",
            "Gener",
            "Gifrer",
            "GIS",
            "Good web",
            "Grenke",
            "GSA Connect",
            "Handipharm",
            "Handipharm via Esker",
            "Hartmann",
            "Herbaethic",
            "Homiris",
            "HygieStore",
            "idc PHARMA",
            "ingenico",
            "Invacare",
            "Izi Pharma",
            "Izivia",
            "Johnson & Johnson",
            "Kiwaki",
            "Kerangal",
            "Keyyo",
            "Kiwaki dolibarr",
            "L'autre Pharmacie",
            "L'oréal",
        ],
    ),
]


def extract_one(image_path, cols, rows, names, out_dir):
    if not os.path.isfile(image_path):
        print(f"  Fichier absent: {image_path}")
        return 0
    img = Image.open(image_path).convert("RGBA")
    w, h = img.size
    cw = w // cols
    ch = h // rows
    saved = 0
    for i, name in enumerate(names):
        if i >= cols * rows:
            break
        if not name or not name.strip():
            continue
        col = i % cols
        row = i // cols
        x1 = col * cw + CELL_PADDING
        y1 = row * ch + CELL_PADDING
        x2 = (col + 1) * cw - CELL_PADDING
        y2 = (row + 1) * ch - CELL_PADDING
        if x2 <= x1 or y2 <= y1:
            continue
        cell = img.crop((x1, y1, x2, y2))
        base = slug(name)
        if not base:
            continue
        path = os.path.join(out_dir, f"{base}.png")
        cell.save(path, "PNG")
        saved += 1
    return saved


def main():
    screenshots_dir = _screenshots_dir()
    print("Dossier captures:", screenshots_dir)
    os.makedirs(ASSETS_ICONS, exist_ok=True)
    total = 0
    seen = set()
    for rel_path, cols, rows, names in SCREENS:
        full = os.path.join(screenshots_dir, rel_path)
        print(f"Traitement: {os.path.basename(rel_path)} ({cols}x{rows}, {len(names)} noms)")
        n = extract_one(full, cols, rows, names, ASSETS_ICONS)
        total += n
        for name in names:
            if name and name.strip():
                s = slug(name)
                if s:
                    seen.add(s)
    print(f"\nTotal: {total} logos enregistrés dans {ASSETS_ICONS}")
    print("Fichiers générés (ex.):", sorted(seen)[:20], "..." if len(seen) > 20 else "")


if __name__ == "__main__":
    main()
