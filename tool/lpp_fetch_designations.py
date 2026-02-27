#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Récupère le libellé (Désignation) LPP depuis les fiches Ameli pour chaque code.

Lit un CSV d'entrée (Code LPP ; URL) ou génère les URLs à partir des codes,
appelle chaque URL, extrait la "Désignation" du HTML et écrit un CSV
Code LPP ; URL ; Libellé (compatible pipeline LPP / loader Flutter).

Dossier CSV source par défaut : C:\\Users\\perra\\OneDrive\\Desktop\\LPP
Fichier par défaut dans ce dossier : codes LPP +++ - codes LPP.csv

Usage:
  # Depuis le dossier source par défaut (pas d'argument input)
  python tool/lpp_fetch_designations.py -o "C:\\Users\\perra\\OneDrive\\Desktop\\LPP\\codes LPP +++ - codes LPP.csv"

  # Depuis un CSV explicite
  python tool/lpp_fetch_designations.py "C:\\Users\\perra\\OneDrive\\Desktop\\LPP\\codes LPP +++ - codes LPP.csv" -o "C:\\Users\\perra\\OneDrive\\Desktop\\LPP\\codes LPP +++ - codes LPP.csv"

  # Test (10 premières lignes)
  python tool/lpp_fetch_designations.py -o out.csv --max 10
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
import time
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError

SEP = ";"
URL_TEMPLATE = "https://www.codage.ext.cnamts.fr/cgi/tips/cgi-fiche?p_code_tips={code}&p_date_jo_arrete=%25&p_menu=FICHE&p_site=AMELI"
USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
DELAY_SEC = 0.5  # entre deux requêtes (réduire la charge serveur)
FETCH_TIMEOUT = 90  # secondes par requête (serveur Ameli souvent lent)
FETCH_RETRIES = 4  # tentatives avec backoff en cas de timeout / erreur réseau
RETRY_BASE_DELAY = 3  # secondes avant la 1re retry, puis backoff

# Dossier et fichier CSV source par défaut
DEFAULT_SOURCE_DIR = Path(r"C:\Users\perra\OneDrive\Desktop\LPP")
DEFAULT_CSV_NAME = "codes LPP +++ - codes LPP.csv"


def fetch_designation(url: str, timeout: int = FETCH_TIMEOUT) -> str:
    """Récupère le libellé (Désignation) depuis la page Ameli. Retries avec backoff en cas de timeout/erreur."""
    for attempt in range(FETCH_RETRIES + 1):
        try:
            req = Request(url, headers={"User-Agent": USER_AGENT})
            with urlopen(req, timeout=timeout) as resp:
                raw = resp.read()
                for enc in ("utf-8", "iso-8859-1", "cp1252"):
                    try:
                        html = raw.decode(enc)
                        break
                    except UnicodeDecodeError:
                        continue
                else:
                    html = raw.decode("utf-8", errors="replace")
                return _extract_designation(html)
        except (URLError, HTTPError, OSError, TimeoutError) as e:
            if attempt < FETCH_RETRIES:
                delay = RETRY_BASE_DELAY * (2**attempt)
                print(f"  Tentative {attempt + 1} échouée, retry dans {delay}s: {e}", file=sys.stderr)
                time.sleep(delay)
                continue
            print(f"  Erreur fetch {url[:60]}... : {e}", file=sys.stderr)
            return ""
    return ""


def _extract_designation(html: str) -> str:
    """Extrait le libellé Désignation du HTML (partie sans I/O)."""

    if len(html) < 100:
        return ""

    # Table HTML : Désignation </td> ... </td> <td> VALUE </td>
    m = re.search(
        r"Désignation\s*</t[dh]>\s*<t[dh][^>]*>[\s\S]*?</t[dh]>\s*<t[dh][^>]*>([\s\S]*?)</t[dh]>",
        html,
        re.IGNORECASE,
    )
    if not m:
        m = re.search(r"Désignation[\s\S]*?:\s*([^<]+)", html, re.IGNORECASE)
    if not m:
        return ""

    libelle = m.group(1)
    libelle = re.sub(r"\s+", " ", libelle)
    libelle = libelle.replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", '"')
    return libelle.strip()


def read_input_csv(path: Path) -> list[tuple[str, str]]:
    """Lit un CSV avec colonnes Code LPP, URL (ou Code LPP en première col). Retourne [(code, url), ...]."""
    rows: list[tuple[str, str]] = []
    with path.open(newline="", encoding="utf-8-sig") as f:
        reader = csv.reader(f, delimiter=SEP)
        for row in reader:
            if not row:
                continue
            raw = (row[0] or "").strip().replace('"', "")
            if not raw or raw.upper() == "CODE LPP" or raw == "lpp":
                continue
            m_code = re.search(r"\d{7}", raw)
            if not m_code:
                continue
            code = m_code.group(0)
            url = (row[1] if len(row) > 1 else URL_TEMPLATE.format(code=code)).strip().replace('"', "")
            if not url or url.upper() == "URL":
                url = URL_TEMPLATE.format(code=code)
            rows.append((code, url))
    return rows


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Récupère les libellés LPP (Désignation) depuis les fiches Ameli et produit un CSV Code LPP ; URL ; Libellé."
    )
    ap.add_argument("input", nargs="?", help="Fichier CSV d'entrée (défaut: dossier LPP sur le Bureau OneDrive)")
    ap.add_argument("-o", "--output", required=True, help="Fichier CSV de sortie (Code LPP ; URL ; Libellé)")
    ap.add_argument("--codes", nargs="*", help="Liste de codes LPP (si pas de fichier input)")
    ap.add_argument("--max", type=int, default=0, help="Nombre max de lignes à traiter (0 = toutes)")
    ap.add_argument("--delay", type=float, default=DELAY_SEC, help=f"Délai en secondes entre requêtes (défaut {DELAY_SEC})")
    ap.add_argument("--timeout", type=int, default=FETCH_TIMEOUT, help=f"Timeout par requête en secondes (défaut {FETCH_TIMEOUT})")
    args = ap.parse_args()

    if args.codes is not None and len(args.codes) > 0:
        data = [(c.strip(), URL_TEMPLATE.format(code=c.strip())) for c in args.codes if re.match(r"^\d{7}$", c.strip())]
        if not data:
            print("Aucun code LPP valide (7 chiffres) dans --codes.", file=sys.stderr)
            sys.exit(1)
    else:
        path = Path(args.input) if args.input else DEFAULT_SOURCE_DIR / DEFAULT_CSV_NAME
        if not path.exists():
            print(f"Fichier introuvable: {path}", file=sys.stderr)
            sys.exit(1)
        data = read_input_csv(path)
        if not data:
            print("Aucune ligne valide dans le CSV.", file=sys.stderr)
            sys.exit(1)

    limit = args.max if args.max > 0 else len(data)
    data = data[:limit]
    out_path = Path(args.output)

    with out_path.open("w", newline="", encoding="utf-8") as f:
        f.write("\ufeff")  # BOM UTF-8
        writer = csv.writer(f, delimiter=SEP, lineterminator="\n")
        writer.writerow(["Code LPP", "URL", "Libellé"])
        for i, (code, url) in enumerate(data):
            libelle = fetch_designation(url, timeout=args.timeout)
            writer.writerow([code, url, libelle])
            f.flush()
            # Affichage CMD : numéro, code LPP, aperçu du libellé récupéré
            preview = (libelle[:50] + "…") if len(libelle) > 50 else (libelle or "—")
            print(f"  [{i + 1}/{len(data)}] {code}  {preview}", flush=True)
            if i < len(data) - 1 and args.delay > 0:
                time.sleep(args.delay)

    print(f"Écrit: {out_path} ({len(data)} lignes)", file=sys.stderr)


if __name__ == "__main__":
    main()
