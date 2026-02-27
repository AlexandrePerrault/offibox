#!/usr/bin/env python3
"""
Récupère les logos des laboratoires via l'API Brandfetch et les enregistre
dans assets/icons du projet s'ils n'existent pas déjà.
Utilise la même logique que fetch_logos.py (OneDrive/Desktop/logos).
"""
import os
import sys
import time

try:
    import requests
except ImportError:
    print("Installation requise: pip install requests")
    sys.exit(1)

# Répertoire du projet = parent du dossier script
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
OUTPUT_DIR = os.path.join(PROJECT_ROOT, "assets", "icons")

API_KEY = "mZZSKHcNmmLx2dK8lyENb3-nU2hpGH7XCpyUwMdMKxeM_Y0v0Di_hEIAI8T5tMtTkxw4BpHcVHnQE66wJ0gSuw"
PREFERRED_FORMATS = ["svg", "png"]

# Liste des laboratoires (lignes 3M à ZAMBON) + mapping nom -> domaine Brandfetch
LABS_AND_DOMAINS = [
    ("3M", "3m.com"),
    ("ABBOTT", "abbott.com"),
    ("ADERMA", "aderma.fr"),
    ("ARKOPHARMA", "arkopharma.com"),
    ("ASEPTA", "asepta.fr"),
    ("AVENE", "eau-thermale-avene.fr"),
    ("BAUSCH LOMB", "bausch.com"),
    ("BAYER", "bayer.com"),
    ("BEAUTERRA", "beauterra.fr"),
    ("BEIERSDORF", "beiersdorf.com"),
    ("BIOCODEX", "biocodex.com"),
    ("BIODERMA", "bioderma.com"),
    ("BIOGYNE", "biogyne.fr"),
    ("BIOSYNEX", "biosynex.com"),
    ("CAPTEUR PROTECT", "capteurprotect.fr"),
    ("CAVAILLES", "cavailles.fr"),
    ("CERAVE", "cerave.com"),
    ("COLGATE", "colgate.com"),
    ("COLOPLAST", "coloplast.com"),
    ("COOPER", "coopervision.com"),
    ("DAYANG", "dayang.com"),
    ("DOCTEUR B", "docteurb.com"),
    ("DSM FIRMENICH", "dsm-firmenich.com"),
    ("DUCRAY", "ducray.com"),
    ("EG LABO", "eglabo.fr"),
    ("EMBECTA", "embecta.com"),
    ("EXPANSCIENCE", "expanscience.com"),
    ("FRESENIUS", "fresenius.com"),
    ("GALLIA BLEDINA", "gallia.fr"),
    ("GILBERT", "gilbert.fr"),
    ("GRIMBERG", "grimberg.fr"),
    ("GSA", "gsa.fr"),
    ("HALEON", "haleon.com"),
    ("IBSA", "ibsa.ch"),
    ("IGLOO", "igloo.fr"),
    ("JOHNSON JOHNSON", "jnj.com"),
    ("KLORANE", "klorane.com"),
    ("LACTALIS", "lactalis.com"),
    ("LA ROCHE POSAY", "laroche-posay.com"),
    ("LES PETITES CHOSES", "lespetiteschoses.fr"),
    ("LIFESCAN", "lifescan.com"),
    ("MAM", "mam-baby.com"),
    ("MAYOLY SPINDLER", "mayoly-spindler.com"),
    ("MELISANA PHARMA", "melisana.fr"),
    ("MENARINI", "menarini.com"),
    ("NESTLE GUIGOZ", "guigoz.fr"),
    ("NUTRAVALIA", "nutravalia.fr"),
    ("NUTRICIA", "nutricia.com"),
    ("NUTRISANTE", "nutrisante.fr"),
    ("ORLIMAN", "orliman.com"),
    ("P&G", "pg.com"),
    ("PERRIGO", "perrigo.com"),
    ("PHILIPS AVENT", "philips.com"),
    ("PIERRE FABRE SANTE", "pierre-fabre.com"),
    ("PRANAROM", "pranarom.com"),
    ("PURESSENTIEL", "puressentiel.com"),
    ("RECORDATI", "recordati.com"),
    ("ROCHE DIABETES", "roche.com"),
    ("SERVIER", "servier.com"),
    ("SUNSTAR GUM", "sunstar.com"),
    ("TEPE", "tepe.com"),
    ("TEVA", "teva.com"),
    ("THEA", "theapharma.com"),
    ("U LABS", "ulabs.fr"),
    ("UPSA", "upsa.com"),
    ("URIAGE", "uriage.com"),
    ("VIATRIS MYLAN", "viatris.com"),
    ("VICHY", "vichy.com"),
    ("ZAMBON", "zambon.com"),
]


def check_connectivity():
    """Verifie que api.brandfetch.com est joignable (evite de boucler sur DNS fail)."""
    try:
        r = requests.get(
            "https://api.brandfetch.com/v2/brands/example.com",
            headers={"Authorization": f"Bearer {API_KEY}"},
            timeout=10,
        )
        return True
    except requests.exceptions.ConnectionError as e:
        err = str(e).replace("'", "")
        print("\n[!] Connexion impossible vers api.brandfetch.com (DNS / reseau).")
        print("    Verifiez : internet, pare-feu, DNS (ex. 8.8.8.8).")
        print(f"    Detail : {err[:80]}...")
        return False
    except Exception:
        return True  # autre erreur (ex. 401) = reseau OK


def get_brand_data(domain, retries=3):
    url = f"https://api.brandfetch.com/v2/brands/{domain}"
    headers = {"Authorization": f"Bearer {API_KEY}"}
    for attempt in range(retries):
        try:
            response = requests.get(url, headers=headers, timeout=15)
            if response.status_code == 200:
                return response.json()
            print(f"  [X] API {response.status_code} pour {domain}")
            return None
        except requests.exceptions.ConnectionError:
            if attempt < retries - 1:
                time.sleep(2)
                continue
            print(f"  [X] Erreur reseau/DNS pour {domain} (apres {retries} essais)")
        except Exception as e:
            print(f"  [X] Erreur pour {domain}: {e}")
            return None
    return None


def save_logo_file(url, filepath):
    try:
        r = requests.get(url, timeout=15)
        r.raise_for_status()
        with open(filepath, "wb") as f:
            f.write(r.content)
        print(f"  OK Telecharge : {os.path.basename(filepath)}")
        return True
    except Exception as e:
        print(f"  Echec : {os.path.basename(filepath)} ({e})")
        return False


def domain_to_basename(domain):
    """Ex: bayer.com -> bayer_com, eau-thermale-avene.fr -> eau-thermale-avene_fr"""
    return domain.replace(".", "_")


def already_exists(domain):
    """Vérifie si un logo pour ce domaine existe déjà dans assets/icons."""
    base = domain_to_basename(domain)
    for ext in ("png", "svg", "jpg", "ico", "webp"):
        if os.path.isfile(os.path.join(OUTPUT_DIR, f"{base}.{ext}")):
            return True
    return False


def main():
    if not os.path.isdir(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)
        print(f"Creation de {OUTPUT_DIR}")

    print(f"Destination : {OUTPUT_DIR}\n")
    if not check_connectivity():
        print("Arret. Relancez quand le reseau est disponible.")
        sys.exit(1)
    print("Connexion API OK.\n")

    for lab_name, domain in LABS_AND_DOMAINS:
        print(f"[?] {lab_name} ({domain})")

        if already_exists(domain):
            print("  (deja present, ignore)")
            continue

        data = get_brand_data(domain)
        if not data or "logos" not in data:
            print("  Pas de logos API.")
            time.sleep(1)
            continue

        found = False
        for logo in data.get("logos", []):
            for fmt in PREFERRED_FORMATS:
                if found:
                    break
                for f in logo.get("formats", []):
                    if f.get("format", "").lower() == fmt:
                        filename = f"{domain_to_basename(domain)}.{fmt}"
                        filepath = os.path.join(OUTPUT_DIR, filename)
                        if os.path.isfile(filepath):
                            print(f"  Existe deja : {filename}")
                            found = True
                            break
                        if save_logo_file(f["src"], filepath):
                            found = True
                        break
            if found:
                break

        if not found:
            print("  Aucun logo enregistre pour ce domaine.")
        time.sleep(1)

    print("\nTermine.")


if __name__ == "__main__":
    main()
