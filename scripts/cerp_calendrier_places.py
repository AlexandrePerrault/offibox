#!/usr/bin/env python3
"""
Scrape le calendrier des formations Académie CERP BA et génère un CSV :
  Col 1 : date
  Col 2 : nom de la formation
  Col 3 : ville (Agence de ..., Classe virtuelle, Hôtel ..., etc.)
  Col 4 : nombre de places restantes

Usage:
  pip install playwright beautifulsoup4
  playwright install chromium
  python scripts/cerp_calendrier_places.py
  python scripts/cerp_calendrier_places.py -o formations_cerp.csv

Planification quotidienne (Windows) :
  - Tâche planifiée : Programmer une tâche pour exécuter ce script chaque jour
  - Ou : pythonw scripts/cerp_calendrier_places.py (en arrière-plan)
"""

import argparse
import csv
import re
import sys
from datetime import datetime
from pathlib import Path

try:
    from playwright.sync_api import sync_playwright
except ImportError:
    print("Erreur: pip install playwright && playwright install chromium", file=sys.stderr)
    sys.exit(1)

try:
    from bs4 import BeautifulSoup
except ImportError:
    print("Erreur: pip install beautifulsoup4", file=sys.stderr)
    sys.exit(1)


URL = "https://www.academiecerpba.fr/nos-formations/calendrier/"
DEFAULT_OUTPUT = "cerp_formations_calendrier.csv"

# Mois en français -> numéro
MOIS_FR = {
    "janvier": 1, "février": 2, "février": 2, "mars": 3, "avril": 4, "mai": 5, "juin": 6,
    "juillet": 7, "août": 8, "septembre": 9, "octobre": 10, "novembre": 11, "décembre": 12,
}

# Jours pour inférer la date (ex: "Jeudi 05" en mars 2026 -> 05/03/2026)
JOURS = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]


def parse_date_cell(text: str, current_month: int, current_year: int) -> str:
    """Extrait une date au format JJ/MM/AAAA depuis une cellule."""
    text = text.strip()
    # Format 05/03/26 ou 09/03/26
    m = re.search(r"(\d{2})/(\d{2})/(\d{2,4})", text)
    if m:
        j, mo, a = m.group(1), m.group(2), m.group(3)
        year = int(a) if len(a) == 4 else 2000 + int(a)
        return f"{j}/{mo}/{year}"
    # Format "Jeudi 05" ou "Lundi 16"
    for jour in JOURS:
        pat = rf"{jour}\s+(\d{{1,2}})\b"
        m = re.search(pat, text, re.I)
        if m:
            j = m.group(1).zfill(2)
            mo = str(current_month).zfill(2)
            return f"{j}/{mo}/{current_year}"
    return ""


def extract_formation_name(html: str) -> str:
    """Extrait le nom de la formation depuis un lien [Nom](url)."""
    m = re.search(r"\[([^\]]+)\]\([^)]+\)", html)
    if m:
        return m.group(1).strip()
    # Fallback: texte entre balises
    soup = BeautifulSoup(html, "html.parser")
    a = soup.find("a")
    if a:
        return a.get_text(strip=True)
    return ""


def extract_places(text: str) -> str:
    """Extrait le nombre de places restantes."""
    m = re.search(r"(\d+)\s+places?\s+restantes?", text, re.I)
    if m:
        return m.group(1)
    return ""


def extract_location(cell_text: str) -> str:
    """Extrait la ville/lieu (Agence X, Classe virtuelle, Hôtel X, etc.)."""
    # La 3e colonne du tableau contient souvent le lieu
    text = cell_text.strip()
    # Nettoyer les parties horaires
    text = re.sub(r"\d{1,2}:\d{2}\s*→\s*\d{1,2}:\d{2}(?:\s+\d{2}/\d{2}/\d{2})?", "", text)
    text = re.sub(r"\[\s*[^\]]+\]\s*\([^)]+\)", "", text)
    text = re.sub(r"Présentiel|À distance|DPC", "", text, flags=re.I)
    text = re.sub(r"\d+\s+places?\s+restantes?", "", text, flags=re.I)
    return text.strip() or ""


def scrape_calendrier() -> list[dict]:
    """Scrape la page et retourne une liste de dicts {date, formation, ville, places}."""
    rows = []
    current_month = 3
    current_year = 2026
    last_date = ""

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        page.goto(URL, wait_until="networkidle", timeout=30000)
        html = page.content()
        browser.close()

    # Debug: sauvegarder le HTML (passer --debug en ligne de commande)
    if "--debug" in sys.argv:
        debug_path = Path(__file__).parent.parent / "debug_cerp_page.html"
        debug_path.write_text(html, encoding="utf-8")
        print(f"HTML sauvegardé: {debug_path}", flush=True)

    soup = BeautifulSoup(html, "html.parser")

    # Parcourir le DOM pour associer chaque table à son mois (h3 précédent)
    for elem in soup.find_all(["h2", "h3", "table"]):
        if elem.name in ("h2", "h3"):
            t = elem.get_text()
            for nom, num in MOIS_FR.items():
                if nom in t.lower():
                    current_month = num
                    break
            if re.search(r"20\d{2}", t):
                m = re.search(r"20\d{2}", t)
                if m:
                    current_year = int(m.group(0))
        elif elem.name == "table":
            trs = elem.find_all("tr")
            for tr in trs:
                tds = tr.find_all("td")
                if len(tds) < 2:
                    continue
                col1 = tds[0].get_text(separator=" ", strip=True)
                col2 = tds[1].get_text(separator=" ", strip=True) if len(tds) > 1 else ""
                col3 = tds[2].get_text(separator=" ", strip=True) if len(tds) > 2 else ""

                if "---" in col1 or not col2:
                    continue

                date_str = parse_date_cell(col1, current_month, current_year)
                if not date_str:
                    date_str = parse_date_cell(col2, current_month, current_year)
                if date_str:
                    last_date = date_str
                else:
                    date_str = last_date

                formation = extract_formation_name(str(tds[1])) if len(tds) > 1 else ""
                if not formation:
                    formation = extract_formation_name(str(tds[0]))

                ville = col3.strip() if col3 else extract_location(col1)
                if not ville:
                    ville = extract_location(col2)
                # Extraire le lieu de col1 si col3 vide (ex: "Agence X - VILLE (XX)")
                if not ville and ("Agence" in col1 or "Classe virtuelle" in col1 or "Hôtel" in col1):
                    ville = col1
                    # Retirer le préfixe date si présent
                    for j in JOURS:
                        ville = re.sub(rf"^{j}\s+\d{{1,2}}\s+", "", ville, flags=re.I)

                places = extract_places(col2) or extract_places(col1)

                if formation or date_str or ville or places:
                    rows.append({
                        "date": date_str,
                        "formation": formation or col2[:80],
                        "ville": ville or col1[:80],
                        "places": places,
                    })

    # Fallback: chercher des blocs avec "places restantes"
    if not rows:
        for elem in soup.find_all(string=re.compile(r"places?\s+restantes?", re.I)):
            parent = elem.parent
            if not parent:
                continue
            text = parent.get_text(separator=" ", strip=True)
            formation = extract_formation_name(str(parent)) or ""
            places = extract_places(text)
            if places:
                # Essayer d'extraire date et lieu du contexte
                date_str = ""
                ville = ""
                for p in parent.parents:
                    if p.name in ("tr", "td", "div"):
                        t = p.get_text(separator=" ", strip=True)
                        if not date_str:
                            date_str = parse_date_cell(t, current_month, current_year)
                        if not ville and ("Agence" in t or "Classe virtuelle" in t or "Hôtel" in t):
                            ville = extract_location(t)
                    if date_str and ville:
                        break
                rows.append({
                    "date": date_str,
                    "formation": formation or text[:80],
                    "ville": ville or "",
                    "places": places,
                })

    return rows


def main():
    parser = argparse.ArgumentParser(description="Exporte le calendrier CERP BA en CSV")
    parser.add_argument("-o", "--output", default=DEFAULT_OUTPUT, help="Fichier CSV de sortie")
    parser.add_argument(
        "--append-date",
        action="store_true",
        help="Ajoute la date du jour au nom du fichier (ex: cerp_2026-02-27.csv) pour les exécutions quotidiennes",
    )
    parser.add_argument("--debug", action="store_true", help="Sauvegarde le HTML de la page dans debug_cerp_page.html")
    args = parser.parse_args()

    try:
        print(f"Chargement de {URL}...", flush=True)
        rows = scrape_calendrier()
    except Exception as e:
        print(f"Erreur: {e}", file=sys.stderr, flush=True)
        raise

    if not rows:
        print("Aucune formation trouvée. La structure de la page a peut-être changé.")
        sys.exit(1)

    out_path = Path(args.output)
    if args.append_date:
        today = datetime.now().strftime("%Y-%m-%d")
        stem = out_path.stem
        out_path = out_path.parent / f"{stem}_{today}{out_path.suffix}"

    fieldnames = ["date", "formation", "ville", "places"]
    with open(out_path, "w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, delimiter=";")
        w.writeheader()
        w.writerows(rows)

    print(f"{len(rows)} formations exportées vers {out_path}")
    sys.exit(0)


if __name__ == "__main__":
    main()
