#!/usr/bin/env python3
"""
Reconstruit le libellé des médicaments BDPM selon le tutoriel officiel :
  "Contenu et format des fichiers téléchargeables dans la BDM" (PDF v4).
Source : https://base-donnees-publique.medicaments.gouv.fr/telechargement

Produit :
  1) bdm_total.csv — une ligne par présentation (CIP13) avec toutes les colonnes
     des fichiers CIS_bdpm, CIS_CIP_bdpm, CIS_COMPO (dosage agrégé), etc.
  2) bdm_libelle_cip13.csv — colonne A = Libellé (nom, dosage, forme galénique,
     nombre d'unités par boîte), colonne B = CIP13.

Libellé = "Dénomination, dosage, forme galénique, libellé de présentation"
  - Dénomination et forme depuis CIS_bdpm.txt
  - Dosage depuis CIS_COMPO_bdpm.txt (substances actives)
  - Libellé de présentation = CIS_CIP_bdpm.txt col 2 (ex. "1 boîte de 30 comprimés")

Usage: python bdm_build_libelle_and_csv.py [--out-dir DIR]
  Par défaut écrit dans scripts/bdm_output/ (créé si besoin).
"""
from __future__ import annotations

import csv
import re
import sys
from pathlib import Path

try:
    import requests
except ImportError:
    print("Dépendance: pip install requests")
    sys.exit(1)

# URLs officielles BDPM (tutoriel PDF v4)
BASE = "https://base-donnees-publique.medicaments.gouv.fr/download/file"
# Désactivé après une SSLError pour permettre les téléchargements en environnement restreint
_verify_ssl = True

FILES = {
    "CIS_bdpm": f"{BASE}/CIS_bdpm.txt",
    "CIS_CIP_bdpm": f"{BASE}/CIS_CIP_bdpm.txt",
    "CIS_COMPO_bdpm": f"{BASE}/CIS_COMPO_bdpm.txt",
    "CIS_CPD_bdpm": f"{BASE}/CIS_CPD_bdpm.txt",
    "CIS_GENER_bdpm": f"{BASE}/CIS_GENER_bdpm.txt",
    "CIS_HAS_SMR_bdpm": f"{BASE}/CIS_HAS_SMR_bdpm.txt",
    "CIS_HAS_ASMR_bdpm": f"{BASE}/CIS_HAS_ASMR_bdpm.txt",
    "HAS_LiensPageCT_bdpm": f"{BASE}/HAS_LiensPageCT_bdpm.txt",
    "CIS_CIP_Dispo_Spec": f"{BASE}/CIS_CIP_Dispo_Spec.txt",
    "CIS_MITM": f"{BASE}/CIS_MITM.txt",
}


def fetch(url: str, timeout: int = 120) -> str | None:
    global _verify_ssl
    try:
        r = requests.get(url, timeout=timeout, verify=_verify_ssl)
        if r.status_code != 200:
            return None
        return decode_content(r.content)
    except requests.exceptions.SSLError as e:
        if _verify_ssl:
            print("SSL échoué, nouvel essai sans vérification...", file=sys.stderr)
            _verify_ssl = False
            return fetch(url, timeout=timeout)
        print(f"Erreur SSL {url}: {e}", file=sys.stderr)
        return None
    except Exception as e:
        print(f"Erreur {url}: {e}", file=sys.stderr)
        return None


# Colonnes (PDF : pas d'en-tête, séparateur tabulation)
# CIS_bdpm: 0=CIS, 1=Dénomination, 2=Forme pharmaceutique, 3=Voies admin, 4=Statut AMM, 5=Type proc AMM, 6=Etat comm, 7=Date AMM, 8=StatutBdm, 9=AMM eur, 10=Titulaire(s), 11=Surveillance
CIS_BDPM_COLS = ["CIS", "Denomination", "Forme_pharmaceutique", "Voies_administration", "Statut_AMM", "Type_procedure_AMM", "Etat_commercialisation", "Date_AMM", "StatutBdm", "Numero_AMM_europeenne", "Titulaires", "Surveillance_renforcee"]

# CIS_CIP_bdpm: 0=CIS, 1=CIP7, 2=Libelle_presentation, 3=Statut_pres, 4=Etat_comm, 5=Date_declaration, 6=CIP13, 7=Agrement_collectivites, 8=Taux_remboursement, 9=Prix_medicament, 10=Prix_public_France, 11=Honoraires_dispensation, 12=Indications_remboursement
CIS_CIP_COLS = ["CIS", "CIP7", "Libelle_presentation", "Statut_presentation", "Etat_commercialisation", "Date_declaration_commercialisation", "CIP13", "Agrement_collectivites", "Taux_remboursement", "Prix_medicament_euro", "Prix_public_France_euro", "Honoraires_dispensation_euro", "Indications_remboursement"]

# CIS_COMPO: 0=CIS, 1=Designation_element, 2=Code_substance, 3=Denomination_substance, 4=Dosage, 5=Reference_dosage, 6=Nature (SA/ST), 7=Numero_liaison
CIS_COMPO_COLS = ["CIS", "Designation_element", "Code_substance", "Denomination_substance", "Dosage_substance", "Reference_dosage", "Nature_composant", "Numero_liaison"]

# Colonne O = CIP_Libelle_presentation (index 14 dans bdm_total.csv)
COL_O_LIBELLE_PRESENTATION_INDEX = 14

# Mots-clés après lesquels on coupe jusqu'à " de " (ordre : plus long en premier)
_LIBELLE_O_KEYWORDS = [
    r"stylo\s+prérempli\s+de\s+0[,.]35\s*ml",
    r"récipient\s*\(\s*s\s*\)\s+unidose\s*\(\s*s\s*\)",
    r"seringue\s*\(\s*s\s*\)\s+préremplie\s*\(\s*s\s*\)",
    r"Kit\s+d'initiation",
    r"1\s+cartouche\s*\(\s*s\s*\)",
    r"flacon\s*\(\s*s\s*\)",
    r"inhalateur\s*\(\s*s\s*\)",
    r"poche\s*\(\s*s\s*\)",
    r"1\s+pot\s*\(\s*s\s*\)",
    r"film\s*\(\s*s\s*\)",
    r"plaquette\s*\(\s*s\s*\)",
    r"ampoule\s*\(\s*s\s*\)",
    r"1\s+bouteille\s*\(\s*s\s*\)",
    r"1\s+bouteille\b",
    r"tube\s*\(\s*s\s*\)",
    r"tubes\b",
    r"tube\b",
    r"sachets\b",
    r"sachet\b",
    r"récipient\s*\(\s*s\s*\)\s+unidose",
    r"récipient\s*\(\s*s\s*\)",
    r"seringue\s*\(\s*s\s*\)",
    r"inhalateur\s*\(\s*s\s*\)",
    r"plaquette",
    r"ampoule",
    r"flacon",
    r"1\s+pot",
    r"1\s+cartouche",
    r"poche",
    r"film",
]
_LIBELLE_O_PATTERNS = [re.compile(p, re.IGNORECASE) for p in _LIBELLE_O_KEYWORDS]


def _clean_col_o_libelle_presentation(text: str) -> str:
    """Coupe après le premier mot-clé trouvé jusqu'à ' de ' (conserve keyword + ' de ' + suite)."""
    if not text or " de " not in text:
        return text
    best_start = -1
    best_keyword_end = -1
    best_de_idx = -1
    for pat in _LIBELLE_O_PATTERNS:
        m = pat.search(text)
        if not m:
            continue
        kw_end = m.end()
        de_idx = text.find(" de ", kw_end)
        if de_idx == -1:
            continue
        if best_start == -1 or m.start() < best_start:
            best_start = m.start()
            best_keyword_end = kw_end
            best_de_idx = de_idx
    if best_de_idx == -1:
        return text
    part1 = text[:best_keyword_end]
    part2 = text[best_de_idx + 4 :].strip()
    # 1ère partie : enlever "(s)" (ex. plaquette(s) → plaquette)
    part1 = re.sub(r"\s*\(\s*s\s*\)", "", part1, flags=re.IGNORECASE)
    part1 = re.sub(r"\s+", " ", part1).strip()
    # 2e partie : "(s)" → "s" sauf si le chiffre devant est 1 ou "un" (garder singulier)
    part2 = _normalize_plural_second_part(part2)
    return part1 + " de " + part2


def _normalize_plural_second_part(part2: str) -> str:
    """Dans la 2e partie du libellé (après ' de ') : (s) → s, sauf après 1 ou un (garder singulier)."""
    # Singulariser "1 mot(s)" et "un mot(s)" (ne pas mettre de s)
    part2 = re.sub(
        r"(^|\s)(1)\s+(\w+)\(\s*s\s*\)",
        r"\1\2 \3",
        part2,
        flags=re.IGNORECASE,
    )
    part2 = re.sub(
        r"(^|\s)(un)\s+(\w+)\(\s*s\s*\)",
        r"\1\2 \3",
        part2,
        flags=re.IGNORECASE,
    )
    # Remplacer tout "(s)" restant par "s" (pluriel)
    part2 = re.sub(r"\(\s*s\s*\)", "s", part2, flags=re.IGNORECASE)
    return re.sub(r"\s+", " ", part2).strip()


def _extract_prefix_before_de(text: str) -> str:
    """Retourne le préfixe avant le premier ' de ' (pour signaler les autres mots)."""
    idx = text.find(" de ")
    if idx == -1:
        return text.strip()[:60]
    return text[:idx].strip()


def decode_content(raw: bytes) -> str:
    for enc in ("utf-8", "latin-1", "cp1252"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode("utf-8", errors="replace")


def parse_tsv(text: str) -> list[list[str]]:
    return [line.split("\t") for line in text.strip().splitlines() if line.strip()]


def norm(s: str) -> str:
    return s.replace("\t", " ").replace("\n", " ").strip() if s else ""


def clean_cis(s: str) -> str:
    return re.sub(r"\D", "", s).strip()


def clean_cip13(s: str) -> str:
    c = re.sub(r"\D", "", s).strip()
    return c if len(c) == 13 else ""


def build_cis_by_code(rows: list[list[str]]) -> dict[str, list[str]]:
    """CIS -> liste de valeurs (colonnes CIS_BDPM_COLS)."""
    out: dict[str, list[str]] = {}
    for row in rows:
        if not row:
            continue
        cis = clean_cis(row[0])
        if not cis:
            continue
        if cis not in out:
            out[cis] = [norm(row[i]) if i < len(row) else "" for i in range(len(CIS_BDPM_COLS))]
    return out


def build_compo_by_cis(rows: list[list[str]]) -> dict[str, str]:
    """CIS -> texte dosage agrégé (substances actives SA : "substance : dosage pour référence")."""
    out: dict[str, list[str]] = {}
    for row in rows:
        if len(row) < 6:
            continue
        cis = clean_cis(row[0])
        if not cis:
            continue
        nature = (row[6] if len(row) > 6 else "").strip().upper()
        if nature != "SA":
            continue
        denom_sub = norm(row[3]) if len(row) > 3 else ""
        dosage = norm(row[4]) if len(row) > 4 else ""
        ref = norm(row[5]) if len(row) > 5 else ""
        if not denom_sub and not dosage:
            continue
        phrase = f"{denom_sub} : {dosage} pour {ref}".strip(" : pour")
        out.setdefault(cis, []).append(phrase)
    return {cis: " ; ".join(phrases) for cis, phrases in out.items()}


def build_libelle(denomination: str, forme: str, dosage_texte: str, libelle_presentation: str) -> str:
    """Libellé = nom du médicament, dosage, forme galénique, nombre d'unités par boîte (libellé présentation)."""
    parts = []
    if denomination:
        parts.append(denomination.strip())
    if dosage_texte:
        parts.append(dosage_texte.strip())
    if forme:
        parts.append(forme.strip())
    if libelle_presentation and libelle_presentation.lower() not in ("présentation active", "présentation abrogée", ""):
        parts.append(libelle_presentation.strip())
    return ", ".join(p for p in parts if p)


def main() -> None:
    out_dir = Path(__file__).resolve().parent / "bdm_output"
    if "--out-dir" in sys.argv:
        i = sys.argv.index("--out-dir")
        if i + 1 < len(sys.argv):
            out_dir = Path(sys.argv[i + 1])
    out_dir.mkdir(parents=True, exist_ok=True)

    print("Téléchargement des fichiers BDPM...")
    cis_text = fetch(FILES["CIS_bdpm"])
    cip_text = fetch(FILES["CIS_CIP_bdpm"])
    compo_text = fetch(FILES["CIS_COMPO_bdpm"])
    if not cis_text or not cip_text:
        print("Échec: CIS_bdpm ou CIS_CIP_bdpm indisponible.", file=sys.stderr)
        sys.exit(1)

    cis_rows = parse_tsv(cis_text)
    cip_rows = parse_tsv(cip_text)
    compo_rows = parse_tsv(compo_text) if compo_text else []

    cis_by_code = build_cis_by_code(cis_rows)
    compo_by_cis = build_compo_by_cis(compo_rows)

    # Télécharger les autres fichiers pour le CSV total (optionnel, peut être long)
    other_data: dict[str, list[list[str]]] = {}
    for name, url in FILES.items():
        if name in ("CIS_bdpm", "CIS_CIP_bdpm", "CIS_COMPO_bdpm"):
            continue
        print(f"  {name}...", end=" ", flush=True)
        txt = fetch(url)
        if txt:
            other_data[name] = parse_tsv(txt)
            print(f"ok ({len(other_data[name])} lignes)")
        else:
            print("skip")

    # En-têtes CSV total : spécialité (CIS_*) + présentation (CIP_*) + compo_dosage
    total_header = (
        ["CIS"] + [f"CIS_{c}" for c in CIS_BDPM_COLS[1:]]
        + [f"CIP_{c}" for c in CIS_CIP_COLS]
        + ["compo_dosage_texte"]
    )
    total_rows: list[list[str]] = []
    other_col_o_prefixes: set[str] = set()

    # CSV simple : Libellé, CIP13
    simple_rows: list[list[str]] = [["Libellé", "CIP13"]]

    for cip_row in cip_rows:
        if len(cip_row) <= 6:
            continue
        cip13 = clean_cip13(cip_row[6])
        if len(cip13) != 13:
            continue
        cis = clean_cis(cip_row[0])
        cis_vals = cis_by_code.get(cis, [""] * len(CIS_BDPM_COLS))
        # Étendre à la bonne longueur
        while len(cis_vals) < len(CIS_BDPM_COLS):
            cis_vals.append("")
        cis_vals = cis_vals[: len(CIS_BDPM_COLS)]

        cip_vals = [norm(cip_row[i]) if i < len(cip_row) else "" for i in range(len(CIS_CIP_COLS))]
        if len(cip_vals) < len(CIS_CIP_COLS):
            cip_vals.extend([""] * (len(CIS_CIP_COLS) - len(cip_vals)))

        denomination = cis_vals[1] if len(cis_vals) > 1 else ""
        forme = cis_vals[2] if len(cis_vals) > 2 else ""
        libelle_pres = cip_vals[2] if len(cip_vals) > 2 else ""
        dosage_texte = compo_by_cis.get(cis, "")

        # Nettoyage colonne O (CIP_Libelle_presentation) : couper après un mot-clé jusqu'à " de "
        if libelle_pres and " de " in libelle_pres:
            cleaned = _clean_col_o_libelle_presentation(libelle_pres)
            if cleaned == libelle_pres and libelle_pres.strip():
                other_col_o_prefixes.add(_extract_prefix_before_de(libelle_pres))
            cip_vals[2] = cleaned

        libelle = build_libelle(denomination, forme, dosage_texte, cip_vals[2])
        simple_rows.append([libelle, cip13])

        row_total = cis_vals + cip_vals + [dosage_texte]
        total_rows.append(row_total)

    # Écrire CSV simple (Libellé, CIP13)
    simple_path = out_dir / "bdm_libelle_cip13.csv"
    with open(simple_path, "w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f, delimiter=";", quoting=csv.QUOTE_MINIMAL)
        w.writerows(simple_rows)
    print(f"Écrit: {simple_path} ({len(simple_rows)-1} lignes)")

    # Écrire CSV total (colonne O = CIP_Libelle_presentation déjà nettoyée)
    total_path = out_dir / "bdm_total.csv"
    with open(total_path, "w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f, delimiter=";", quoting=csv.QUOTE_MINIMAL)
        w.writerow(total_header)
        w.writerows(total_rows)
    print(f"Écrit: {total_path} ({len(total_rows)} lignes)")

    if other_col_o_prefixes:
        print("\nAutres mots/phrases rencontrés dans la colonne O (non dans la liste des mots-clés):")
        for p in sorted(other_col_o_prefixes):
            if p:
                print(f"  - {p[:80]}{'...' if len(p) > 80 else ''}")

    print("Terminé.")


if __name__ == "__main__":
    main()
