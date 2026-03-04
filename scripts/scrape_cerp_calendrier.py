#!/usr/bin/env python3
"""
Scrape le calendrier des formations Académie CERP BA.
Génère un CSV : date, nom_formation, ville, places_restantes.
À exécuter quotidiennement pour suivre les places restantes.
"""
from __future__ import annotations

import csv
import re
import sys
from pathlib import Path

try:
    import requests
    from bs4 import BeautifulSoup
except ImportError:
    print("Dépendances requises: pip install requests beautifulsoup4")
    sys.exit(1)

URL = "https://www.academiecerpba.fr/nos-formations/calendrier/"

# Mois français -> numéro
MOIS_FR = {
    "janvier": 1, "février": 2, "mars": 3, "avril": 4, "mai": 5, "juin": 6,
    "juillet": 7, "août": 8, "septembre": 9, "octobre": 10, "novembre": 11, "décembre": 12,
}

# Jours français (pour extraire le numéro du jour)
JOUR_PATTERN = re.compile(
    r"(lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche)\s+(\d{1,2})",
    re.IGNORECASE,
)

# Date au format DD/MM/YY dans le texte
DATE_DDMMYY = re.compile(r"(\d{2})/(\d{2})/(\d{2})")

# Places restantes
PLACES_PATTERN = re.compile(r"(\d+)\s+places?\s+restantes?", re.IGNORECASE)


def fetch_page() -> str:
    """Récupère le HTML de la page calendrier."""
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    }
    r = requests.get(URL, headers=headers, timeout=30)
    r.raise_for_status()
    return r.text


def parse_date_from_col1(text: str, current_month: int, year: int = 2026) -> str | None:
    """
    Extrait la date depuis la colonne 1 (ex: "Jeudi 05 Agence...", "Lundi 09 Agence...").
    Retourne YYYY-MM-DD ou None.
    """
    m = JOUR_PATTERN.search(text)
    if m:
        day = int(m.group(2))
        return f"{year:04d}-{current_month:02d}-{day:02d}"
    return None


def parse_date_from_col2(text: str) -> str | None:
    """
    Extrait la date depuis la colonne 2 (ex: "09/03/26 9:00", "16/03/26 9:00").
    Retourne YYYY-MM-DD ou None.
    """
    m = DATE_DDMMYY.search(text)
    if m:
        d, mo, y = int(m.group(1)), int(m.group(2)), int(m.group(3))
        year = 2000 + y if y < 50 else 1900 + y
        return f"{year:04d}-{mo:02d}-{d:02d}"
    return None


def parse_formation(text: str) -> str:
    """Extrait le nom de la formation depuis [Nom](url)."""
    m = re.search(r"\[([^\]]+)\]", text)
    return m.group(1).strip() if m else ""


def parse_places(text: str) -> str:
    """Extrait le nombre de places restantes."""
    m = PLACES_PATTERN.search(text)
    return m.group(1) if m else ""


def parse_calendrier(html: str) -> list[dict]:
    """Parse le HTML et retourne une liste de dicts {date, formation, ville, places}."""
    soup = BeautifulSoup(html, "html.parser")
    rows: list[dict] = []
    current_month = 0
    current_year = 2026

    # Trouver les sections par mois (h2/h3 avec "Mars", "Avril", etc.)
    for tag in soup.find_all(["h2", "h3"]):
        t = (tag.get_text() or "").strip()
        for nom, num in MOIS_FR.items():
            if nom in t.lower():
                current_month = num
                ym = re.search(r"20\d{2}", t)
                if ym:
                    current_year = int(ym.group(0))
                break

    # Trouver les tables
    tables = soup.find_all("table")
    for table in tables:
        for tr in table.find_all("tr"):
            cells = tr.find_all(["td", "th"])
            if len(cells) < 3:
                continue
            c1 = (cells[0].get_text() or "").strip()
            c2 = (cells[1].get_text() or "").strip()
            c3 = (cells[2].get_text() or "").strip()

            if "---" in c1 or "---" in c2:
                continue

            formation = parse_formation(c2)
            if not formation:
                continue

            places = parse_places(c2)
            ville = c3.strip() or c1

            date_str = parse_date_from_col2(c2)
            if not date_str:
                date_str = parse_date_from_col1(c1, current_month, current_year)
            if not date_str:
                date_str = ""

            rows.append({
                "date": date_str,
                "formation": formation,
                "ville": ville,
                "places": places,
            })

    return rows


def main() -> None:
    out_path = Path(__file__).parent.parent / "cerp_calendrier_formations.csv"
    if len(sys.argv) > 1:
        out_path = Path(sys.argv[1])

    print(f"Fetching {URL}...")
    html = fetch_page()
    rows = parse_calendrier(html)
    print(f"Found {len(rows)} formations")

    with open(out_path, "w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=["date", "formation", "ville", "places"])
        w.writeheader()
        w.writerows(rows)

    print(f"CSV written to {out_path}")


if __name__ == "__main__":
    main()
