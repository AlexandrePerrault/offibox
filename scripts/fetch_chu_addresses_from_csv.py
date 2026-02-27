#!/usr/bin/env python3
"""
Lit un CSV CHU (colonnes: nom, adresse, ..., telephone, email, url),
récupère les adresses depuis les URLs (lannuaire.service-public.gouv.fr)
et écrit un nouveau CSV avec la colonne adresse remplie.

Usage:
  python scripts/fetch_chu_addresses_from_csv.py "<chemin/vers/annuaires-CHU.csv>"
  python scripts/fetch_chu_addresses_from_csv.py "entree.csv" "sortie.csv"
"""

import csv
import os
import re
import sys
import time
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError


def fetch(url: str) -> str:
    req = Request(url, headers={"User-Agent": "Mozilla/5.0 (compatible; Offibox/1.0)"})
    with urlopen(req, timeout=15) as r:
        return r.read().decode("utf-8", errors="replace")


def extract_address_from_html(html: str) -> str:
    """Extrait l'adresse (section Lieu) depuis le HTML d'une fiche annuaire."""
    m = re.search(
        r"Lieu\s*</[^>]+>\s*</[^>]+>\s*([^<]+?)(?:<|Voir sur une carte)",
        html,
        re.DOTALL | re.I,
    )
    if m:
        return re.sub(r"\s+", " ", m.group(1).strip())
    m = re.search(
        r'(?:Adresse|Lieu)[^>]*>[\s\S]*?<[^>]+>[\s]*([0-9][^<]{10,200})',
        html,
        re.I,
    )
    if m:
        return re.sub(r"\s+", " ", m.group(1).strip())
    return ""


def main() -> int:
    script_dir = os.path.dirname(os.path.abspath(__file__))

    if len(sys.argv) >= 2:
        input_path = os.path.abspath(sys.argv[1])
    else:
        print("Usage: python fetch_chu_addresses_from_csv.py <entree.csv> [sortie.csv]", file=sys.stderr)
        return 1

    if len(sys.argv) >= 3:
        output_path = os.path.abspath(sys.argv[2])
    else:
        base, ext = os.path.splitext(input_path)
        output_path = f"{base}_avec_adresses{ext}"

    if not os.path.isfile(input_path):
        print(f"Fichier introuvable: {input_path}", file=sys.stderr)
        return 1

    rows = []
    with open(input_path, "r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        fieldnames = list(reader.fieldnames or [])
        for row in reader:
            rows.append(row)

    if not rows:
        print("CSV vide.", file=sys.stderr)
        return 1

    key_url = None
    key_adresse = None
    for k in rows[0]:
        kc = (k or "").strip().lower()
        if kc == "url":
            key_url = k
        if kc == "adresse":
            key_adresse = k
    if not key_url:
        for k in rows[0]:
            if k and "url" in k.lower():
                key_url = k
                break
    if not key_adresse:
        for k in rows[0]:
            if k and "adresse" in k.lower():
                key_adresse = k
                break
    key_url = key_url or "url"
    key_adresse = key_adresse or "adresse"

    print(f"Lecture: {input_path} ({len(rows)} lignes)")
    print("Recuperation des adresses...")

    for i, row in enumerate(rows):
        url = (row.get(key_url) or "").strip()
        if not url or not url.startswith("http"):
            continue
        try:
            html = fetch(url)
            addr = extract_address_from_html(html)
            if addr:
                row[key_adresse] = addr
                print(f"  [{i+1}/{len(rows)}] {addr[:60]}...")
            else:
                print(f"  [{i+1}/{len(rows)}] (non trouve) {url[:50]}...")
        except Exception as e:
            print(f"  [{i+1}/{len(rows)}] Erreur: {e}", file=sys.stderr)
        time.sleep(0.35)

    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)

    print(f"\nFichier ecrit: {output_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
