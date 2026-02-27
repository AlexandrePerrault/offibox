#!/usr/bin/env python3
"""
Telecharge les logos des sources (BDM, DGS, Vidal, Coloplast, etc.) via Brandfetch
et les enregistre dans assets/icons. Affiche et enregistre la liste des chemins.
"""
import os
import sys
import time

try:
    import requests
except ImportError:
    print("Installation requise: pip install requests")
    sys.exit(1)

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
OUTPUT_DIR = os.path.join(PROJECT_ROOT, "assets", "icons")

API_KEY = "mZZSKHcNmmLx2dK8lyENb3-nU2hpGH7XCpyUwMdMKxeM_Y0v0Di_hEIAI8T5tMtTkxw4BpHcVHnQE66wJ0gSuw"
PREFERRED_FORMATS = ["svg", "png"]

# Nom affiche -> domaine Brandfetch (certains sites .gouv n'ont pas de logo sur Brandfetch)
SOURCES_AND_DOMAINS = [
    ("base de données publiques sur le médicament", "base-donnees-publique.medicaments.gouv.fr"),
    ("DGS urgent", "solidarites-sante.gouv.fr"),
    ("pharmaradio", "pharmaradio.fr"),
    ("le moniteur des pharmacies", "lemoniteurdespharmacies.fr"),
    ("le quotidien du pharmacien", "lequotidiendopharmacien.fr"),
    ("ordre national des pharmaciens", "ordre.pharmaciens.fr"),
    ("vidal", "vidal.fr"),
    ("thériaque", "theriaque.org"),
    ("vigirupture", "vigirupture.fr"),
    ("posos", "posos.fr"),
    ("Pharmalia (PHOENIX OCP)", "phoenixgroup.eu"),
    ("Lohmann et Rauscher", "lohmann-rauscher.com"),
    ("Coloplast (pansements)", "coloplast.com"),
    ("Coloplast (uro et colostomie)", "coloplast.com"),
    ("convatec", "convatec.com"),
    ("Hartmann", "hartmann.info"),
    ("Urgo Médical", "urgomedical.com"),
    ("Smith & Nephew", "smith-nephew.com"),
    ("Meddispar", "meddispar.fr"),
    ("Mailiz", "mailiz.fr"),
    ("doctolib Pro", "doctolib.fr"),
    ("annuaire santé", "sante.fr"),
    ("recommandations sanitaires aux voyageurs", "diplomatie.gouv.fr"),
    ("Thuasne (compression)", "thuasne.com"),
    ("Sigvaris", "sigvaris.com"),
    ("Innothera-Gibaud", "innothera.fr"),
    ("Thuasne (orthopédie)", "thuasne.com"),
    ("Orliman", "orliman.com"),
    ("Radiante", "radiante.fr"),
    ("Madouest", "madouest.fr"),
    ("Cerp équipement", "cerp.fr"),
]


def domain_to_basename(domain):
    return domain.replace(".", "_")


def get_brand_data(domain, retries=2):
    url = f"https://api.brandfetch.com/v2/brands/{domain}"
    headers = {"Authorization": f"Bearer {API_KEY}"}
    for attempt in range(retries):
        try:
            r = requests.get(url, headers=headers, timeout=12)
            if r.status_code == 200:
                return r.json()
            return None
        except Exception:
            if attempt < retries - 1:
                time.sleep(2)
    return None


def save_logo_file(url, filepath):
    try:
        r = requests.get(url, timeout=12)
        r.raise_for_status()
        with open(filepath, "wb") as f:
            f.write(r.content)
        return True
    except Exception:
        return False


def already_exists(domain):
    base = domain_to_basename(domain)
    for ext in ("png", "svg", "jpg", "ico", "webp"):
        if os.path.isfile(os.path.join(OUTPUT_DIR, f"{base}.{ext}")):
            return True
    return False


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    paths = []

    for name, domain in SOURCES_AND_DOMAINS:
        base = domain_to_basename(domain)
        existing = None
        for ext in ("png", "svg", "jpg", "ico", "webp"):
            p = os.path.join(OUTPUT_DIR, f"{base}.{ext}")
            if os.path.isfile(p):
                existing = p
                break
        if existing:
            rel = os.path.relpath(existing, PROJECT_ROOT).replace("\\", "/")
            paths.append((name, rel))
            print(f"[OK] Deja present: {name} -> {rel}")
            continue

        data = get_brand_data(domain)
        if not data or "logos" not in data:
            paths.append((name, f"assets/icons/{base}.png  # NON TROUVE"))
            print(f"[--] Pas de logo API: {name} ({domain})")
            time.sleep(0.8)
            continue

        found = False
        for logo in data.get("logos", []):
            for fmt in PREFERRED_FORMATS:
                if found:
                    break
                for f in logo.get("formats", []):
                    if f.get("format", "").lower() == fmt:
                        filename = f"{base}.{fmt}"
                        filepath = os.path.join(OUTPUT_DIR, filename)
                        if save_logo_file(f["src"], filepath):
                            rel = os.path.relpath(filepath, PROJECT_ROOT).replace("\\", "/")
                            paths.append((name, rel))
                            print(f"[+] Telecharge: {name} -> {rel}")
                            found = True
                        break
            if found:
                break
        if not found:
            paths.append((name, f"assets/icons/{base}.png  # ECHEC"))
            print(f"[X] Echec: {name}")
        time.sleep(1)

    out_txt = os.path.join(PROJECT_ROOT, "scripts", "source_logos_paths.txt")
    with open(out_txt, "w", encoding="utf-8") as f:
        f.write("# Nom -> chemin dans le projet (assets/icons)\n")
        f.write("# Utiliser dans le code: assets/icons/nom_fichier.png ou .svg\n\n")
        for name, path in paths:
            f.write(f"{name}\t{path}\n")
    print(f"\nListe des chemins ecrite dans: {out_txt}")
    return paths


if __name__ == "__main__":
    main()
