#!/usr/bin/env python3
"""
Complète un CSV Santralia réparé en ajoutant les URLs de logos manquantes.

Entrée : CSV avec au moins les colonnes : Code, Libellé, URL laboratoire (PDF), URL logo (image)
Sortie : même CSV (ou nouveau fichier) avec la colonne logo remplie quand possible.
"""

import argparse
import csv
import json
import re
import sys
import unicodedata
from pathlib import Path
from urllib.parse import unquote


def normalize_key(s: str) -> str:
    s = (s or "").strip().upper()
    if not s:
        return ""
    nfd = unicodedata.normalize("NFD", s)
    s = "".join(c for c in nfd if unicodedata.category(c) != "Mn")
    s = re.sub(r"[^A-Z0-9 ]+", " ", s)
    return " ".join(s.split())


def sniff_delimiter(sample: str) -> str:
    for d in (",", ";", "\t"):
        if sample.count(d) > 1:
            return d
    return ","


def load_logo_map(urls_json_path: str, prefix: str) -> dict[str, str]:
    data = json.load(open(urls_json_path, "r", encoding="utf-8"))
    if not isinstance(data, list):
        raise ValueError("urls-json doit être une liste")

    prefix = prefix.rstrip("/") + "/"
    logos_marker = f"{prefix}LOGOS PARTENAIRES/".upper()
    best: dict[str, tuple[int, str]] = {}

    for it in data:
        if not isinstance(it, dict):
            continue
        path = str(it.get("path") or "")
        url = str(it.get("url") or "")
        name = str(it.get("name") or "")
        if not path or not url or not name:
            continue
        if logos_marker not in path.upper():
            continue

        # extension image seulement
        name_dec = unquote(name)
        m = re.match(r"^(.*)\.(png|jpg|jpeg|svg|webp|gif)$", name_dec, flags=re.IGNORECASE)
        if not m:
            continue
        base = m.group(1)
        base = base.replace("_", " ")
        # couper les suffixes fréquents
        base = re.split(r"(\bID\b|\bLOGO\b)", base, maxsplit=1, flags=re.IGNORECASE)[0].strip()
        key = normalize_key(base)
        if not key:
            continue

        score = len(name_dec)
        prev = best.get(key)
        if prev is None or score < prev[0]:
            best[key] = (score, url)

    return {k: v for k, (_, v) in best.items()}


def labkey_from_pdf_url(pdf_url: str) -> str:
    # Ex: .../o/SANTRALIA-CATALOGUE%202025%2FABBOTT.pdf?alt=media&token=...
    u = (pdf_url or "").strip()
    if not u:
        return ""
    # prendre la partie avant ? puis dernier segment après %2F ou /
    base = u.split("?", 1)[0]
    last = base.rsplit("%2F", 1)[-1].rsplit("/", 1)[-1]
    last = unquote(last)
    if last.lower().endswith(".pdf"):
        last = last[:-4]
    return normalize_key(last)


def main() -> None:
    ap = argparse.ArgumentParser(description="Remplit les URLs de logos manquantes dans un CSV Santralia.")
    ap.add_argument("--input", "-i", required=True)
    ap.add_argument("--urls-json", required=True)
    ap.add_argument("--output", "-o", required=True)
    ap.add_argument("--prefix", default="SANTRALIA-CATALOGUE 2025")
    args = ap.parse_args()

    in_path = Path(args.input)
    if not in_path.is_file():
        print(f"Erreur: fichier introuvable: {in_path}", file=sys.stderr)
        raise SystemExit(1)

    logo_by_lab = load_logo_map(args.urls_json, args.prefix)
    sample = in_path.read_text(encoding="utf-8-sig", errors="replace")[:4096]
    delim = sniff_delimiter(sample)

    out_path = Path(args.output)
    filled = 0
    total = 0

    with open(in_path, "r", encoding="utf-8-sig", newline="") as f_in, open(out_path, "w", encoding="utf-8-sig", newline="") as f_out:
        reader = csv.reader(f_in, delimiter=delim)
        writer = csv.writer(f_out, delimiter=delim, quoting=csv.QUOTE_MINIMAL)

        header = next(reader, None)
        if header is None:
            raise SystemExit("CSV vide")
        writer.writerow(header)

        # indices attendus
        # Code, Libellé, URL laboratoire (PDF), URL logo (image)
        for row in reader:
            if not row:
                continue
            total += 1
            while len(row) < 4:
                row.append("")
            pdf_url = row[2]
            logo_url = row[3].strip()
            if not logo_url:
                labkey = labkey_from_pdf_url(pdf_url)
                if labkey:
                    candidate = logo_by_lab.get(labkey, "")
                    if candidate:
                        row[3] = candidate
                        filled += 1
            writer.writerow(row)

    print(f"Terminé: logos ajoutés {filled}/{total} -> {out_path}", file=sys.stderr)


if __name__ == "__main__":
    main()

