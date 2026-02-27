#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script ANSM → CSV génériques / princeps pour Offibox.

Télécharge fic01den.txt (DCI) et fic03spe.txt (spécialités G/R),
construit un CSV avec : DCI ; princeps_nom ; princeps_cip ; cip13
pour afficher en ligne 2 "Princeps : X" / "Générique : X".

Usage:
  python tool/ansm_generiques_csv.py [--output fichier.csv]
  Par défaut : génère generiques_ansm.csv à la racine du projet.

Sources ANSM (à mettre à jour si besoin) :
  https://ansm.sante.fr/uploads/2026/01/20/fic01den.txt
  https://ansm.sante.fr/uploads/2026/01/20/fic03spe.txt
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from collections import defaultdict
from pathlib import Path

try:
    import urllib.request
    URLLIB = True
except Exception:
    URLLIB = False

# URLs par défaut (ANSM)
FIC01DEN_URL = "https://ansm.sante.fr/uploads/2026/01/20/fic01den.txt"
FIC03SPE_URL = "https://ansm.sante.fr/uploads/2026/01/20/fic03spe.txt"


def fetch(url: str) -> str:
    if URLLIB:
        req = urllib.request.Request(url, headers={"User-Agent": "Offibox/1.0"})
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.read().decode("utf-8", errors="replace")
    raise RuntimeError("urllib non disponible")


def parse_fic01den(content: str) -> list[tuple[int, str]]:
    """Parse fic01den : une ligne = 'ID DCI_NAME' → [(id, dci), ...]"""
    out = []
    for line in content.splitlines():
        line = line.strip()
        if not line:
            continue
        m = re.match(r"^(\d+)\s+(.+)$", line)
        if m:
            out.append((int(m.group(1)), m.group(2).strip()))
    return out


def parse_fic03spe(content: str) -> list[tuple[int, str, str, str]]:
    """
    Parse fic03spe : code_spe ; cip8 ; G|R ; libellé...
    Returns: [(code_spe, cip8, type, label), ...]
    """
    out = []
    for line in content.splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split(None, 3)  # max 4 champs
        if len(parts) < 4:
            continue
        code_spe = int(parts[0])
        cip8 = parts[1].strip()
        typ = parts[2].strip().upper()
        label = parts[3].strip()
        if typ not in ("G", "R", "S"):
            continue
        out.append((code_spe, cip8, typ, label))
    return out


def cip8_to_cip13(cip8: str) -> str | None:
    """Construit un CIP13 à 13 chiffres à partir du code 8 chiffres (CIS/CIP)."""
    digits = re.sub(r"\D", "", cip8)
    if len(digits) == 8:
        return "34009" + digits  # 5 + 8 = 13
    if len(digits) == 7:
        # clé de contrôle Luhn-like souvent utilisée pour CIP13
        base = "34009" + digits
        return base + str((10 - sum(int(b) * (1 if i % 2 == 0 else 2) for i, b in enumerate(base)) % 10) % 10)
    return None


def normalize_dci_for_match(s: str) -> str:
    """Réduit une DCI pour matching (majuscules, sans accents approximatif)."""
    s = s.upper()
    for old, new in [("'", " "), ("(", " "), (")", " "), ("-", " "), ("  ", " ")]:
        s = s.replace(old, new)
    return " ".join(s.split())


def find_dci_for_label(label: str, dci_list: list[tuple[int, str]]) -> str:
    """
    Trouve la DCI (fic01den) qui correspond au début du libellé.
    Ex. "ABACAVIR ARROW 300 mg" → "ABACAVIR (SULFATE D')" ou "ABACAVIR".
    """
    if not dci_list or not label:
        return ""
    label_upper = label.upper()
    first_word = label_upper.split()[0] if label_upper.split() else ""
    if not first_word:
        return ""
    best = ""
    best_len = 0
    for _id, dci in dci_list:
        dci_norm = normalize_dci_for_match(dci)
        dci_main = dci_norm.split(" - ")[0].strip()
        words = dci_main.split()
        if not words or words[0] != first_word:
            continue
        # Le premier mot matche ; on garde la DCI la plus longue (meilleure précision)
        if len(dci_main) > best_len:
            best = dci
            best_len = len(dci_main)
    return best


def main() -> int:
    parser = argparse.ArgumentParser(description="Génère le CSV génériques/princeps depuis les fichiers ANSM")
    parser.add_argument("--output", "-o", default="generiques_ansm.csv", help="Fichier CSV de sortie")
    parser.add_argument("--fic01", default=FIC01DEN_URL, help="URL fic01den.txt")
    parser.add_argument("--fic03", default=FIC03SPE_URL, help="URL fic03spe.txt")
    parser.add_argument("--no-fetch", action="store_true", help="Utiliser les fichiers locaux (fic01den.txt, fic03spe.txt)")
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    project_root = script_dir.parent
    output_path = Path(args.output)
    if not output_path.is_absolute():
        output_path = project_root / output_path

    # Charger fic01den (DCI)
    if args.no_fetch:
        fic01_path = project_root / "fic01den.txt"
        fic03_path = project_root / "fic03spe.txt"
        if not fic01_path.exists() or not fic03_path.exists():
            print("Fichiers fic01den.txt / fic03spe.txt introuvables. Lancez sans --no-fetch.", file=sys.stderr)
            return 1
        fic01_content = fic01_path.read_text(encoding="utf-8", errors="replace")
        fic03_content = fic03_path.read_text(encoding="utf-8", errors="replace")
    else:
        print("Téléchargement fic01den...")
        fic01_content = fetch(args.fic01)
        print("Téléchargement fic03spe...")
        fic03_content = fetch(args.fic03)

    dci_list = parse_fic01den(fic01_content)
    spe_list = parse_fic03spe(fic03_content)
    print(f"fic01den: {len(dci_list)} DCI, fic03spe: {len(spe_list)} spécialités")

    # Grouper par code_spe ; pour chaque groupe, séparer R (princeps) et G (génériques)
    by_code: dict[int, list[tuple[str, str, str]]] = defaultdict(list)
    for code_spe, cip8, typ, label in spe_list:
        cip13 = cip8_to_cip13(cip8)
        if not cip13:
            continue
        by_code[code_spe].append((typ, cip13, label))

    # Pour chaque groupe : référent(s) R = princeps, G = génériques
    rows = []
    for code_spe, items in by_code.items():
        refs = [(cip13, label) for t, cip13, label in items if t == "R"]
        gens = [(cip13, label) for t, cip13, label in items if t == "G"]
        if not refs and not gens:
            continue
        # Un princeps "représentatif" (premier R)
        princeps_cip = refs[0][0] if refs else ""
        princeps_nom = refs[0][1] if refs else ""
        for cip13, label in gens:
            dci = find_dci_for_label(label, dci_list) if dci_list else ""
            rows.append(
                {
                    "dci": dci,
                    "princeps_nom": princeps_nom,
                    "princeps_cip": princeps_cip,
                    "cip13": cip13,
                }
            )
        # Lignes princeps (CIP = princeps_cip) pour CSV complet "DCI ; CIP ; princeps ; cip princeps"
        for cip13, label in refs:
            dci = find_dci_for_label(label, dci_list) if dci_list else ""
            rows.append(
                {
                    "dci": dci,
                    "princeps_nom": label,
                    "princeps_cip": cip13,
                    "cip13": cip13,
                }
            )

    # Écrire CSV (séparateur ; pour compatibilité app Offibox)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter=";", quoting=csv.QUOTE_MINIMAL)
        w.writerow(["DCI", "princeps_nom", "princeps_cip", "cip13"])
        for r in rows:
            w.writerow([r["dci"], r["princeps_nom"], r["princeps_cip"], r["cip13"]])

    # Statistiques : uniquement les lignes "génériques" (princeps_cip != cip13) pour l’app
    generiques_only = [r for r in rows if r["princeps_cip"] and r["princeps_cip"] != r["cip13"]]
    print(f"Lignes écrites: {len(rows)} (dont {len(generiques_only)} génériques avec princeps)")
    print(f"CSV écrit: {output_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
