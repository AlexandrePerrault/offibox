#!/usr/bin/env python3
"""
Exporte les coordonnées des 32 CHU depuis l'annuaire Service Public.
Usage: python scripts/export_chu_coordinates.py
Génère: chu_coordonnees.csv (et chu_coordonnees.json)
"""

import csv
import json
import re
import sys
import time
from urllib.parse import urljoin
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError

BASE = "https://lannuaire.service-public.gouv.fr"
LIST_URL = f"{BASE}/navigation/chu"
# Page 2 si pagination (certains sites utilisent ?page=2 ou offset)
LIST_URL_PAGE2 = f"{BASE}/navigation/chu?page=2"
# Pattern pour les liens vers une fiche (contient un UUID)
UUID_PATTERN = re.compile(
    r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}",
    re.I,
)


def fetch(url: str) -> str:
    req = Request(url, headers={"User-Agent": "Mozilla/5.0 (compatible; Offibox/1.0)"})
    with urlopen(req, timeout=15) as r:
        return r.read().decode("utf-8", errors="replace")


def extract_links_listing(html: str) -> list[str]:
    """Extrait les URLs des fiches CHU depuis la page listing."""
    links = []
    for m in re.finditer(r'href="([^"]+)"', html):
        path = m.group(1).split("#")[0].strip()
        if UUID_PATTERN.search(path) and "lannuaire.service-public" in path:
            full = path if path.startswith("http") else urljoin(BASE, path)
            if full not in links:
                links.append(full)
    return links


def extract_detail(html: str, url: str) -> dict:
    """Extrait nom, adresse, lat, lon, téléphone, email, site depuis le HTML d'une fiche."""
    out = {
        "url": url,
        "nom": "",
        "adresse": "",
        "latitude": "",
        "longitude": "",
        "telephone": "",
        "email": "",
        "site_web": "",
    }
    # Nom (titre h1)
    m = re.search(r'<h1[^>]*>([^<]+)</h1>', html, re.DOTALL | re.I)
    if m:
        out["nom"] = re.sub(r"\s+", " ", m.group(1).strip())
    # Lieu / adresse (section Lieu, bloc après "Lieu")
    m = re.search(r"Lieu\s*</[^>]+>\s*</[^>]+>\s*([^<]+?)(?:<|Voir sur une carte)", html, re.DOTALL | re.I)
    if m:
        out["adresse"] = re.sub(r"\s+", " ", m.group(1).strip())
    # Coordonnées depuis "Voir sur une carte" (mlat=...&mlon=...)
    m = re.search(r"mlat=([0-9.-]+).*?mlon=([0-9.-]+)", html)
    if m:
        out["latitude"] = m.group(1).strip()
        out["longitude"] = m.group(2).strip()
    # Téléphone (lien tel:)
    m = re.search(r'tel:([0-9\s.]+)"', html)
    if m:
        out["telephone"] = re.sub(r"\s", "", m.group(1))
    # Email
    m = re.search(r'mailto:([^"\s]+@[^"\s]+)"', html)
    if m:
        out["email"] = m.group(1).strip()
    # Site web (section Contacts, lien https)
    m = re.search(r"Site web\s*</[^>]+>\s*<a[^>]+href=\"(https://[^\"]+)\"", html, re.I)
    if m:
        out["site_web"] = m.group(1).strip()
    return out


def main() -> int:
    print("Récupération de la page liste CHU...")
    try:
        list_html = fetch(LIST_URL)
    except (URLError, HTTPError) as e:
        print(f"Erreur liste: {e}", file=sys.stderr)
        return 1
    links = extract_links_listing(list_html)
    # Tenter une 2e page pour récupérer les 12 résultats suivants (32 au total)
    try:
        list_html2 = fetch(LIST_URL_PAGE2)
        links2 = extract_links_listing(list_html2)
        for u in links2:
            if u not in links:
                links.append(u)
    except Exception:
        pass
    # Déduplication et filtrage (garder seulement les fiches détaillées, pas les ancres)
    links = [u for u in links if UUID_PATTERN.search(u) and u.count("/") >= 4][:50]
    if not links:
        print("Aucun lien CHU trouvé. Vérifiez le HTML de la page.", file=sys.stderr)
        return 1
    print(f"Trouvé {len(links)} fiches. Récupération des détails...")
    results = []
    for i, url in enumerate(links):
        try:
            html = fetch(url)
            row = extract_detail(html, url)
            results.append(row)
            print(f"  [{i+1}/{len(links)}] {row['nom'][:50] or url}")
        except Exception as e:
            print(f"  Erreur {url}: {e}", file=sys.stderr)
            results.append({"url": url, "nom": "", "adresse": "", "latitude": "", "longitude": "", "telephone": "", "email": "", "site_web": ""})
        time.sleep(0.3)
    # Export CSV (dans le dossier du script)
    import os
    _dir = os.path.dirname(os.path.abspath(__file__))
    csv_path = os.path.join(_dir, "chu_coordonnees.csv")
    with open(csv_path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["nom", "adresse", "latitude", "longitude", "telephone", "email", "site_web", "url"])
        w.writeheader()
        w.writerows(results)
    print(f"\nCSV écrit: {csv_path}")
    # Export JSON
    json_path = os.path.join(_dir, "chu_coordonnees.json")
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
    print(f"JSON écrit: {json_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
