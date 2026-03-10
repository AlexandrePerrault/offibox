#!/usr/bin/env python3
"""
Pipeline Annuaire PS 2026 : télécharge le fichier data.gouv (PS_LibreAcces_Personne_activite),
nettoie les données, les injecte dans une feuille Google Sheets et exporte en CSV vers GitHub.

Prérequis :
  pip install gspread google-auth

Configuration :
  1. Google Cloud : projet avec API Sheets, compte de service, fichier JSON.
  2. Partager le spreadsheet avec l’email du compte de service (éditeur).
  3. GOOGLE_APPLICATION_CREDENTIALS ou --credentials.
  4. GITHUB_TOKEN (scope repo) pour l’export vers GitHub.

Exécution quotidienne (ex. 8h) :
  - Linux/Mac : crontab -e → 0 8 * * * /usr/bin/python3 /chemin/scripts/annuaire_ps_2026_pipeline.py
  - Windows : Planificateur de tâches, déclencher tous les jours à 8h.

Usage :
  python scripts/annuaire_ps_2026_pipeline.py [--url URL] [--no-sheets] [--no-github] [--no-profession-filter]

Par défaut, seules certaines professions sont conservées : médecins, pharmaciens (en sortie :
nom de la pharmacie, adresse, téléphone uniquement — pas le nom du pharmacien), infirmiers/IDE/IPA,
chirurgiens-dentistes, sages-femmes, orthophonistes, orthoptistes, kinés, ergothérapeutes, pédicures,
ostéopathes, psychologues. Plusieurs lieux d'exercice = une ligne par lieu. Un fichier CSV par profession (annuaire_medecins_2026.csv, annuaire_pharmacies_2026.csv, etc.) dans annuaire_ps_2026_output/ et sur GitHub.
"""
from __future__ import annotations

import argparse
import base64
import csv
import io
import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

# URL par défaut (extraction annuaire santé PS - peut changer avec les mises à jour data.gouv)
DEFAULT_SOURCE_URL = (
    "https://static.data.gouv.fr/resources/annuaire-sante-extractions-des-donnees-en-libre-acces-des-professionnels-intervenant-dans-le-systeme-de-sante-rpps/"
    "20260228-094439/ps-libreacces-personne-activite.txt"
)

# Page du jeu de données pour message d'erreur 404 (l'URL statique change à chaque extraction).
DATASET_PAGE_URL = (
    "https://www.data.gouv.fr/datasets/annuaire-sante-extractions-des-donnees-en-libre-acces-des-professionnels-intervenant-dans-le-systeme-de-sante"
)

SPREADSHEET_ID = "1CBHIdBePtr1JhA-UZLSk_jZ5bRBMYIUgBV-3m13Umk4"
SHEET_NAME = "annuaire PS 2026"

GITHUB_OWNER = "AlexandrePerrault"
GITHUB_REPO = "offiboxdata"
GITHUB_BRANCH = "main"
# Chemin GitHub pour l'ancien mode (un seul fichier) ; en mode "un fichier par profession" on utilise {slug}.csv.
GITHUB_PATH_LEGACY = "annuaire PS 2026.csv"

# Taille max d’un batch Sheets (éviter dépassement)
SHEETS_BATCH_SIZE = 1500

# Limite GitHub API (fichiers > 100 Mo refusés par l'API Contents)
GITHUB_CONTENTS_SIZE_LIMIT_BYTES = 99 * (1024 * 1024)

# Dossier local par défaut pour enregistrer le CSV (toujours rempli)
DEFAULT_OUTPUT_DIR = Path(__file__).resolve().parent / "annuaire_ps_2026_output"

# Professions à conserver (libellés tels qu’ils peuvent apparaître dans le fichier source).
# On matche en normalisant : minuscules, espaces/accents ignorés pour la comparaison.
ALLOWED_PROFESSIONS_RAW = [
    "Médecin",
    "Médecins",
    "Pharmacien",
    "Pharmaciens",
    "Pharmacienne",
    "Infirmier",
    "Infirmière",
    "Infirmiers",
    "Infirmières",
    "Masseur",
    "Masseurs",
    "Masseur-Kinésithérapeute",
    "Masseur-kinésithérapeute",
    "Kinésithérapeute",
    "Kinésithérapeutes",
    "Pédicure",
    "Pédicure-Podologue",
    "Pédicure-podologue",
    "Podologue",
    "Podologues",
    "Sage-Femme",
    "Sage-femme",
    "Sage femme",
    "Sages-femmes",
    "Ostéopathe",
    "Ostéopathes",
    "Osteopathe",
    "Psychologue",
    "Psychologues",
    "Chirurgien-Dentiste",
    "Chirurgiens-Dentistes",
    "Chirurgien dentiste",
    "Orthophoniste",
    "Orthophonistes",
    "Orthoptiste",
    "Orthoptistes",
    "Ergothérapeute",
    "Ergothérapeutes",
    "Infirmier en pratique avancée",
    "IPA",
]

# Annuaire PS (format data.gouv) : 1re ligne = en-tête, séparateur |, "Libellé profession" = index 10.
DEFAULT_PROFESSION_COLUMN_INDEX = 10

# Slug de fichier par profession (un fichier CSV par profession sur disque et GitHub).
# Clé = libellé normalisé (ou partie reconnue), valeur = nom de base du fichier (sans .csv).
PROFESSION_SLUG_MAP: list[tuple[list[str], str]] = [
    (["pharmacien", "pharmacienne", "pharmaciens"], "annuaire_pharmacies_2026"),
    (["medecin", "medecins"], "annuaire_medecins_2026"),
    (["infirmier", "infirmiere", "infirmiers", "infirmieres"], "annuaire_infirmiers_2026"),
    (["masseur", "kinesitherapeute", "kinesitherapeutes"], "annuaire_kinesitherapeutes_2026"),
    (["pedicure", "podologue", "pedicure-podologue"], "annuaire_pedicures_podologues_2026"),
    (["sage-femme", "sage femme", "sages-femmes"], "annuaire_sages_femmes_2026"),
    (["osteopathe", "ostéopathe", "osteopathes", "ostéopathes"], "annuaire_osteopathes_2026"),
    (["psychologue", "psychologues"], "annuaire_psychologues_2026"),
    (["chirurgien-dentiste", "chirurgiens-dentistes", "chirurgien dentiste"], "annuaire_chirurgiens_dentistes_2026"),
    (["orthophoniste", "orthophonistes"], "annuaire_orthophonistes_2026"),
    (["orthoptiste", "orthoptistes"], "annuaire_orthoptistes_2026"),
    (["ergotherapeute", "ergothérapeute", "ergotherapeutes", "ergothérapeutes"], "annuaire_ergotherapeutes_2026"),
    (["infirmier en pratique avancee", "ipa"], "annuaire_ipa_2026"),
]


def _normalize_for_profession(s: str) -> str:
    """Normalise une chaîne pour comparaison (minuscules, espaces, accents)."""
    s = (s or "").strip().lower()
    # Remplacement des caractères accentués
    accents = {
        "é": "e", "è": "e", "ê": "e", "ë": "e",
        "à": "a", "â": "a", "ä": "a",
        "ù": "u", "û": "u", "ü": "u",
        "î": "i", "ï": "i",
        "ô": "o", "ö": "o",
        "ç": "c", "œ": "oe",
    }
    for acc, plain in accents.items():
        s = s.replace(acc, plain)
    return re.sub(r"\s+", " ", s).strip()


def _profession_cell_to_slug(cell_value: str) -> str:
    """Retourne le slug de fichier pour une cellule « profession » (ex. Médecin → annuaire_medecins_2026)."""
    norm = _normalize_for_profession(cell_value)
    if not norm:
        return "annuaire_autres_2026"
    for keywords, slug in PROFESSION_SLUG_MAP:
        if any(kw in norm for kw in keywords):
            return slug
    # Fallback : slug à partir de la valeur (nettoyée)
    base = re.sub(r"[^a-z0-9]+", "_", norm).strip("_") or "autres"
    return f"annuaire_{base}_2026"


def group_rows_by_profession(
    rows: list[list[str]],
    profession_col: int,
) -> dict[str, list[list[str]]]:
    """
    Groupe les lignes (en-tête + données) par profession.
    Retourne un dict slug -> [header, row1, row2, ...] avec header = rows[0].
    """
    if not rows or len(rows) < 2:
        return {}
    header = rows[0]
    groups: dict[str, list[list[str]]] = {}
    for row in rows[1:]:
        if profession_col >= len(row):
            continue
        slug = _profession_cell_to_slug(row[profession_col])
        if slug not in groups:
            groups[slug] = [header]
        groups[slug].append(row)
    return groups


def _find_profession_column_index(header_row: list[str]) -> int | None:
    """Retourne l’index (0-based) de la colonne 'profession' dans la première ligne, ou None."""
    norm_header = [_normalize_for_profession(c) for c in header_row]
    for i, h in enumerate(norm_header):
        if h.strip() == "libelle profession":
            return i
    for i, h in enumerate(norm_header):
        if "profession" in h and "code" not in h:
            return i
    for i, h in enumerate(norm_header):
        if "profession" in h:
            return i
    for i, h in enumerate(norm_header):
        if "libelle" in h and ("profession" in h or "activite" in h):
            return i
    for i, h in enumerate(norm_header):
        if "activite" in h or "metier" in h:
            return i
    return None


def filter_by_professions(
    rows: list[list[str]],
    allowed_raw: list[str],
    profession_col: int | None = None,
) -> list[list[str]]:
    """
    Garde l’en-tête et les lignes dont la profession est dans allowed_raw.
    Si profession_col est None, tente de le détecter depuis la première ligne.
    """
    if not rows or len(rows) < 2:
        return rows
    header = rows[0]
    idx = profession_col if profession_col is not None else _find_profession_column_index(header)
    if idx is None and len(header) > DEFAULT_PROFESSION_COLUMN_INDEX:
        idx = DEFAULT_PROFESSION_COLUMN_INDEX
        print(
            "  Colonne profession non detectee, utilisation index %s (--profession-col pour changer)." % idx,
            file=sys.stderr,
            flush=True,
        )
    if idx is None:
        return rows
    allowed_norm = {_normalize_for_profession(p) for p in allowed_raw}
    out = [header]
    seen_values = set()
    for row in rows[1:]:
        if idx >= len(row):
            continue
        cell_norm = _normalize_for_profession(row[idx])
        if not cell_norm:
            continue
        if len(seen_values) < 10:
            seen_values.add(row[idx].strip()[:60])
        # Match si la cellule (normalisée) contient l’un des libellés autorisés
        if any(norm in cell_norm for norm in allowed_norm):
            out.append(row)
    if seen_values and len(out) > 1:
        print("  Colonne profession : index %s. Ex. valeurs : %s" % (idx, list(seen_values)[:5]), file=sys.stderr, flush=True)
    return out


def _col_letter(n: int) -> str:
    """Colonne 1 -> A, 27 -> AA, etc."""
    s = ""
    while n > 0:
        n, r = divmod(n - 1, 26)
        s = chr(65 + r) + s
    return s or "A"


def _col_letter_to_index(letter: str) -> int:
    """Colonne A -> 0, B -> 1, AC -> 28, etc."""
    s = letter.strip().upper()
    n = 0
    for c in s:
        n = n * 26 + (ord(c) - ord("A") + 1)
    return n - 1


# En-tête CSV de sortie : RPPS en col 1, puis nom, prénom, titre, coordonnées, tel, nom structure (tous les lieux d'exercice = une ligne par lieu).
OUT_CSV_HEADER = [
    "RPPS",
    "Nom",
    "Prenom",
    "Titre",
    "Adresse",
    "Code_postal",
    "Ville",
    "Telephone",
    "Nom_structure",
]

# Libellés profession "pharmacien" pour filtrer (normalisés).
PHARMACIEN_NORMS = {_normalize_for_profession(p) for p in ["pharmacien", "pharmacienne", "pharmaciens"]}


def _is_pharmacien_row(row: list[str], profession_col: int) -> bool:
    if profession_col >= len(row):
        return False
    prof_norm = _normalize_for_profession(row[profession_col])
    return any(p in prof_norm for p in PHARMACIEN_NORMS)


def split_pharmaciens_and_others(
    rows: list[list[str]],
    profession_col: int,
) -> tuple[list[list[str]], list[list[str]]]:
    """Sépare en-tête + lignes pharmaciens et en-tête + lignes autres professions. Les deux listes ont l'en-tête en première ligne."""
    if not rows or len(rows) < 2:
        return (rows, [rows[0]] if rows else [])
    header = rows[0]
    pharmaciens = [header]
    others = [header]
    for row in rows[1:]:
        if _is_pharmacien_row(row, profession_col):
            pharmaciens.append(row)
        else:
            others.append(row)
    return (pharmaciens, others)


# En-tête du 2e CSV : pharmacies uniquement (nom, adresse, tél).
PHARMACIES_CSV_HEADER = [
    "Nom_pharmacie",
    "Adresse",
    "Code_postal",
    "Ville",
    "Telephone",
]


def build_pharmacies_output_rows(
    rows: list[list[str]],
    col_indices: dict[str, int | None],
    deduplicate: bool = True,
) -> list[list[str]]:
    """Construit les lignes du CSV pharmacies : nom, adresse, code postal, ville, téléphone.
    Si deduplicate=True (défaut), une seule ligne par établissement (clé : nom + adresse + CP + ville)."""
    out = [PHARMACIES_CSV_HEADER]
    field_map = {
        "Nom_pharmacie": "Nom_structure",
        "Adresse": "Adresse",
        "Code_postal": "Code_postal",
        "Ville": "Ville",
        "Telephone": "Telephone",
    }
    seen: set[tuple[str, str, str, str]] = set()
    for row in rows[1:]:
        out_row = []
        for field in PHARMACIES_CSV_HEADER:
            src_field = field_map[field]
            idx = col_indices.get(src_field)
            if idx is None or idx >= len(row):
                out_row.append("")
                continue
            out_row.append((row[idx] or "").strip())
        if deduplicate:
            key = (out_row[0], out_row[1], out_row[2], out_row[3])  # Nom, Adresse, CP, Ville
            if key in seen:
                continue
            seen.add(key)
        out.append(out_row)
    return out


# Correspondance champ de sortie -> noms possibles de colonnes source (normalisés)
OUTPUT_TO_SOURCE_HEADERS: dict[str, list[str]] = {
    "RPPS": ["identifiant pp", "rpps", "numero rpps", "identifiant_pp", "id_pp"],
    "Nom": ["nom", "nom d'exercice", "nom exercice", "nom_exercice", "nom de naissance"],
    "Prenom": ["prenom", "prenom d'exercice", "prenom exercice", "prenom_exercice"],
    "Titre": ["libelle profession", "profession", "libelle_profession", "activite"],
    "Adresse": ["adresse", "numero voie", "numero_voie", "voie", "adresse structure", "complement adresse"],
    "Code_postal": ["code postal", "code_postal", "cp"],
    "Ville": ["ville", "libelle commune", "libelle_commune", "commune"],
    "Telephone": ["telephone", "tel", "numero telephone"],
    "Nom_structure": ["raison sociale", "nom structure", "nom_structure", "nom pharmacie", "structure", "libelle structure"],
}


def _find_column_index(header_row: list[str], possible_names: list[str]) -> int | None:
    """Retourne l'index (0-based) de la première colonne dont le libellé normalisé matche un des noms, ou None."""
    allowed = {_normalize_for_profession(n) for n in possible_names}
    norm_header = [_normalize_for_profession(c) for c in header_row]
    for i, h in enumerate(norm_header):
        h = (h or "").strip()
        if not h:
            continue
        if h in allowed:
            return i
        if any(a in h or h in a for a in allowed):
            return i
    return None


def build_output_rows(
    rows: list[list[str]],
    profession_col: int,
    col_indices: dict[str, int | None],
) -> list[list[str]]:
    """
    Construit les lignes du CSV de sortie (RPPS col 1, nom, prénom, titre, coordonnées, tel, nom_structure).
    Pour les pharmaciens : on ne garde pas le nom/prénom du professionnel, on met le nom de la pharmacie (structure).
    Une ligne par lieu d'exercice (plusieurs lignes si plusieurs lieux).
    """
    out = [OUT_CSV_HEADER]
    for row in rows[1:]:
        if profession_col >= len(row):
            continue
        prof_norm = _normalize_for_profession(row[profession_col])
        is_pharmacien = any(p in prof_norm for p in PHARMACIEN_NORMS)
        out_row = []
        for field in OUT_CSV_HEADER:
            idx = col_indices.get(field)
            if idx is None or idx >= len(row):
                out_row.append("")
                continue
            val = (row[idx] or "").strip()
            if is_pharmacien and field in ("Nom", "Prenom"):
                val = ""
            if is_pharmacien and field == "Nom_structure" and not val:
                # Fallback : mettre la raison sociale ailleurs si une colonne "nom" structure existe
                pass
            out_row.append(val)
        out.append(out_row)
    return out


def detect_output_columns(header_row: list[str]) -> dict[str, int | None]:
    """Détecte les indices des colonnes source pour chaque champ de sortie."""
    return {
        field: _find_column_index(header_row, names)
        for field, names in OUTPUT_TO_SOURCE_HEADERS.items()
    }


# Colonnes à garder si détection par en-tête échoue (ordre lettres Excel)
CSV_COLUMNS = ["B", "E", "I", "H", "K", "Y", "AC", "AE", "AF", "AG", "AJ", "AL", "AO", "AQ"]


def select_columns(rows: list[list[str]], col_letters: list[str]) -> list[list[str]]:
    """Retourne les lignes en ne gardant que les colonnes données (indices 0-based)."""
    if not rows:
        return []
    indices = [_col_letter_to_index(c) for c in col_letters]
    max_col = max(indices)
    out = []
    for row in rows:
        if len(row) <= max_col:
            row = row + [""] * (max_col - len(row) + 1)
        out.append([row[i] if i < len(row) else "" for i in indices])
    return out


def get_latest_annuaire_ps_url() -> str | None:
    """
    Récupère l'URL actuelle du fichier PS_LibreAcces_Personne_activite via l'API data.gouv.fr.
    Retourne None si l'API ne répond pas ou si aucune ressource correspondante n'est trouvée.
    """
    dataset_slug = "annuaire-sante-extractions-des-donnees-en-libre-acces-des-professionnels-intervenant-dans-le-systeme-de-sante"
    api_url = f"https://www.data.gouv.fr/api/1/datasets/{dataset_slug}/"
    try:
        req = Request(api_url, headers={"Accept": "application/json"})
        with urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode())
    except (HTTPError, URLError, json.JSONDecodeError, OSError):
        return None
    resources = data.get("resources") or []
    for r in resources:
        title = (r.get("title") or "").lower()
        url = (r.get("url") or "").lower()
        if "personne_activite" in title or "personne_activite" in url or "personne-activite" in url:
            raw_url = r.get("url")
            if raw_url and isinstance(raw_url, str):
                return raw_url.strip()
    return None


def download_source(url: str, progress_mb_interval: float = 50.0) -> bytes:
    """Télécharge le fichier source en flux avec affichage de progression (UTF-8 ou Latin-1)."""
    # Timeout long pour gros fichiers (700 Mo+)
    with urlopen(url, timeout=1800) as resp:
        chunk_list = []
        total = 0
        next_report = progress_mb_interval * (1024 * 1024)
        while True:
            chunk = resp.read(1024 * 1024)  # 1 Mo par bloc
            if not chunk:
                break
            chunk_list.append(chunk)
            total += len(chunk)
            if total >= next_report:
                print(f"  Téléchargé : {total / (1024 * 1024):.0f} Mo", file=sys.stderr, flush=True)
                next_report = total + progress_mb_interval * (1024 * 1024)
        raw = b"".join(chunk_list)
    print(f"  Total : {len(raw) / (1024 * 1024):.1f} Mo", file=sys.stderr, flush=True)
    return raw


def decode_and_clean_raw(raw: bytes) -> str:
    """Décode en UTF-8 (avec BOM) ou Latin-1, nettoie les retours à la ligne."""
    if raw.startswith(b"\xef\xbb\xbf"):
        text = raw[3:].decode("utf-8")
    else:
        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError:
            text = raw.decode("latin-1")
    return text.replace("\r\n", "\n").replace("\r", "\n").strip()


def detect_delimiter(first_line: str) -> str:
    """Détecte le séparateur (tab, pipe, point-virgule)."""
    if "\t" in first_line and first_line.count("\t") > 1:
        return "\t"
    if "|" in first_line and first_line.count("|") > 1:
        return "|"
    if ";" in first_line:
        return ";"
    return "\t"


def parse_and_clean(text: str) -> list[list[str]]:
    """
    Parse le fichier (délimiteur auto), nettoie chaque cellule :
    strip, suppression espaces multiples internes, lignes vides ignorées.
    """
    lines = text.split("\n")
    if not lines:
        return []
    delim = detect_delimiter(lines[0])
    reader = csv.reader(io.StringIO(text), delimiter=delim)
    rows = []
    for row in reader:
        cleaned = []
        for cell in row:
            s = str(cell).strip()
            s = re.sub(r"\s+", " ", s)
            cleaned.append(s)
        if any(cleaned):
            rows.append(cleaned)
    return rows


def normalize_row_length(rows: list[list[str]], num_cols: int | None = None) -> list[list[str]]:
    """Aligne le nombre de colonnes (longueur de la première ligne ou num_cols)."""
    if not rows:
        return rows
    target = num_cols or len(rows[0])
    out = []
    for row in rows:
        if len(row) < target:
            row = row + [""] * (target - len(row))
        else:
            row = row[:target]
        out.append(row)
    return out


def upload_to_sheets(rows: list[list[str]], credentials_path: str | Path) -> None:
    """Envoie les lignes vers la feuille Google Sheets (batch)."""
    try:
        import gspread
        from google.oauth2.service_account import Credentials
    except ImportError:
        print("pip install gspread google-auth", file=sys.stderr)
        sys.exit(1)

    creds = Credentials.from_service_account_file(
        str(credentials_path),
        scopes=["https://www.googleapis.com/auth/spreadsheets"],
    )
    gc = gspread.authorize(creds)
    sh = gc.open_by_key(SPREADSHEET_ID)
    try:
        sheet = sh.worksheet(SHEET_NAME)
    except gspread.WorksheetNotFound:
        sheet = sh.add_worksheet(
            title=SHEET_NAME,
            rows=min(len(rows) + 500, 100000),
            cols=min(len(rows[0]) if rows else 20, 50),
        )

    sheet.clear()
    if not rows:
        print("Aucune donnée à envoyer vers Sheets.", file=sys.stderr)
        return
    ncols = len(rows[0])
    total_batches = (len(rows) + SHEETS_BATCH_SIZE - 1) // SHEETS_BATCH_SIZE
    for batch_idx, i in enumerate(range(0, len(rows), SHEETS_BATCH_SIZE), start=1):
        chunk = rows[i : i + SHEETS_BATCH_SIZE]
        start = i + 1
        end = i + len(chunk)
        range_a1 = f"A{start}:{_col_letter(ncols)}{end}"
        sheet.update(range_a1, chunk, value_input_option="USER_ENTERED")
        print(f"  Sheets : batch {batch_idx}/{total_batches} (lignes {start}-{end})", file=sys.stderr, flush=True)
    print(f"Feuille « {SHEET_NAME} » mise à jour : {len(rows)} lignes.")


def build_csv_content(rows: list[list[str]], delimiter: str = ";") -> str:
    """Construit le contenu CSV (UTF-8, séparateur ;)."""
    buf = io.StringIO()
    writer = csv.writer(buf, delimiter=delimiter, lineterminator="\n", quoting=csv.QUOTE_MINIMAL)
    for row in rows:
        writer.writerow(row)
    return buf.getvalue()


def push_to_github(csv_content: str, token: str, github_path: str | None = None) -> None:
    """Envoie le CSV vers le dépôt GitHub (PUT contents API). github_path = chemin du fichier dans le repo (ex. annuaire_medecins_2026.csv)."""
    path = github_path or GITHUB_PATH_LEGACY
    path_encoded = quote(path, safe="")
    api_url = f"https://api.github.com/repos/{GITHUB_OWNER}/{GITHUB_REPO}/contents/{path_encoded}"
    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github.v3+json",
        "Content-Type": "application/json",
    }

    # Récupérer le sha si le fichier existe
    req_get = Request(api_url, headers={k: v for k, v in headers.items() if k != "Content-Type"})
    try:
        with urlopen(req_get) as resp:
            data = json.loads(resp.read().decode())
            sha = data.get("sha")
    except Exception:
        sha = None

    content_b64 = base64.b64encode(csv_content.encode("utf-8")).decode("ascii")
    message = f"MAJ {path} – {datetime.now().strftime('%Y-%m-%d %H:%M')}"
    payload = {"message": message, "content": content_b64, "branch": GITHUB_BRANCH}
    if sha:
        payload["sha"] = sha

    req_put = Request(
        api_url,
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="PUT",
    )
    with urlopen(req_put) as resp:
        if resp.status not in (200, 201):
            raise RuntimeError(f"GitHub API: {resp.status} {resp.read()}")
    print(f"Export GitHub : {path} ({GITHUB_OWNER}/{GITHUB_REPO} {GITHUB_BRANCH}).")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Télécharge l’annuaire PS, nettoie, envoie vers Sheets et exporte en CSV sur GitHub."
    )
    parser.add_argument(
        "--url",
        default=DEFAULT_SOURCE_URL,
        help="URL du fichier ps-libreacces-personne-activite.txt",
    )
    parser.add_argument(
        "--credentials",
        type=Path,
        default=os.environ.get("GOOGLE_APPLICATION_CREDENTIALS"),
        help="Chemin vers le JSON du compte de service Google",
    )
    parser.add_argument(
        "--no-sheets",
        action="store_true",
        help="Ne pas envoyer vers Google Sheets",
    )
    parser.add_argument(
        "--no-github",
        action="store_true",
        help="Ne pas pousser vers GitHub",
    )
    parser.add_argument(
        "--max-rows",
        type=int,
        default=0,
        help="Limiter le nombre de lignes (0 = tout)",
    )
    parser.add_argument(
        "--max-columns",
        type=int,
        default=0,
        help="Limiter le nombre de colonnes (0 = toutes les colonnes définies : %s)" % ", ".join(CSV_COLUMNS),
    )
    parser.add_argument(
        "--output",
        "-o",
        type=Path,
        default=None,
        help="Ignoré : un fichier par profession est écrit dans annuaire_ps_2026_output/ (conservé pour compatibilité)",
    )
    parser.add_argument(
        "--output-pharmacies",
        type=Path,
        default=None,
        help="Ignoré : annuaire_pharmacies_2026.csv est dans annuaire_ps_2026_output/ (conservé pour compatibilité)",
    )
    parser.add_argument(
        "--no-profession-filter",
        action="store_true",
        help="Ne pas filtrer par profession (garder tous les PS)",
    )
    parser.add_argument(
        "--pharmacies-only",
        action="store_true",
        help="Extraire uniquement les établissements pharmacie (CSV dédoublonné, ~20 000 lignes). Équivalent à filtrer pharmaciens puis dédupliquer par (nom, adresse, CP, ville).",
    )
    parser.add_argument(
        "--profession-col",
        type=int,
        default=None,
        metavar="INDEX",
        help="Index 0-based de la colonne profession si auto-détection échoue",
    )
    args = parser.parse_args()

    print("Téléchargement (fichier potentiellement gros, patience)...", file=sys.stderr, flush=True)
    url = args.url
    try:
        raw = download_source(url)
    except HTTPError as e:
        if e.code != 404:
            raise
        if url != DEFAULT_SOURCE_URL:
            raise
        print("L'URL par défaut n'est plus valide (404). Tentative de récupération de l'URL actuelle...", file=sys.stderr, flush=True)
        latest = get_latest_annuaire_ps_url()
        if latest:
            print(f"  Nouvelle URL : {latest[:80]}...", file=sys.stderr, flush=True)
            raw = download_source(latest)
        else:
            print(
                f"Impossible de récupérer l'URL automatiquement.\n"
                f"Allez sur le jeu de données : {DATASET_PAGE_URL}\n"
                f"Téléchargez la ressource « PS_LibreAcces_Personne_activite » (ou équivalent), "
                f"récupérez l'URL du fichier .txt et relancez avec :\n  --url <URL>",
                file=sys.stderr,
            )
            sys.exit(1)
    print("Décodage et nettoyage du texte...", file=sys.stderr, flush=True)
    text = decode_and_clean_raw(raw)
    del raw  # libérer la mémoire le plus tôt possible
    print("Parsing CSV et nettoyage des cellules...", file=sys.stderr, flush=True)
    rows = parse_and_clean(text)
    del text
    if not rows:
        print("Aucune ligne après nettoyage.", file=sys.stderr)
        sys.exit(1)
    rows = normalize_row_length(rows)

    profession_col: int | None = args.profession_col
    if args.pharmacies_only:
        before = len(rows)
        rows = filter_by_professions(
            rows,
            ["Pharmacien", "Pharmacienne", "Pharmaciens"],
            profession_col=profession_col,
        )
        print(
            f"Mode pharmacies uniquement : {len(rows) - 1} lignes pharmaciens (sur {before - 1} données).",
            file=sys.stderr,
            flush=True,
        )
    elif not args.no_profession_filter:
        before = len(rows)
        rows = filter_by_professions(
            rows,
            ALLOWED_PROFESSIONS_RAW,
            profession_col=profession_col,
        )
        print(
            f"Filtre profession : {len(rows) - 1} lignes conservées (sur {before - 1} données, + 1 en-tête).",
            file=sys.stderr,
            flush=True,
        )
    if profession_col is None and rows:
        profession_col = _find_profession_column_index(rows[0])
    if profession_col is None:
        profession_col = DEFAULT_PROFESSION_COLUMN_INDEX

    # Grouper par profession → un fichier CSV par profession (local + GitHub)
    groups = group_rows_by_profession(rows, profession_col)
    col_indices = detect_output_columns(rows[0]) if rows else {}
    use_header_based = col_indices.get("RPPS") is not None or col_indices.get("Titre") is not None
    if not use_header_based:
        col_list = CSV_COLUMNS[: args.max_columns] if args.max_columns and args.max_columns > 0 else CSV_COLUMNS
        print("  Colonnes source par lettres (fallback) : %s" % ", ".join(col_list), file=sys.stderr, flush=True)

    DEFAULT_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    rows_for_sheets: list[list[str]] = []  # Données combinées (hors pharmacies) pour la feuille Sheets
    files_pushed: list[tuple[str, Path]] = []
    github_token = None if args.no_github else os.environ.get("GITHUB_TOKEN")
    if not args.no_github and not github_token:
        print("GITHUB_TOKEN non défini : export GitHub ignoré.", file=sys.stderr)

    for slug, group_rows in sorted(groups.items()):
        if len(group_rows) < 2:
            print("  %s : 0 ligne, ignoré." % slug, file=sys.stderr, flush=True)
            continue
        is_pharmacies = slug == "annuaire_pharmacies_2026"
        if is_pharmacies:
            out_rows = build_pharmacies_output_rows(group_rows, col_indices)
        else:
            if use_header_based:
                out_rows = build_output_rows(group_rows, profession_col, col_indices)
            else:
                selected = select_columns(group_rows, col_list)
                if selected:
                    h = OUT_CSV_HEADER[: len(selected[0])] if len(selected[0]) <= len(OUT_CSV_HEADER) else OUT_CSV_HEADER + [""] * (len(selected[0]) - len(OUT_CSV_HEADER))
                    out_rows = [h] + selected[1:]
                else:
                    out_rows = []
            if out_rows and not is_pharmacies:
                rows_for_sheets.extend(out_rows[1:])  # pour Sheets : cumul des lignes (sans re-header à chaque fois)

        if args.max_rows and args.max_rows > 0 and not is_pharmacies:
            out_rows = [out_rows[0]] + out_rows[1 : args.max_rows + 1]

        csv_content = build_csv_content(out_rows)
        csv_bytes = csv_content.encode("utf-8")
        filename = slug + ".csv"
        local_path = DEFAULT_OUTPUT_DIR / filename
        local_path.write_bytes(csv_bytes)
        size_mb = len(csv_bytes) / (1024 * 1024)
        print("  %s : %s (%d lignes, %.2f Mo)" % (slug, local_path, len(out_rows) - 1, size_mb), file=sys.stderr, flush=True)
        files_pushed.append((filename, local_path))

        if not args.no_github and github_token and len(csv_bytes) <= GITHUB_CONTENTS_SIZE_LIMIT_BYTES:
            push_to_github(csv_content, github_token, github_path=filename)
            print("    -> https://raw.githubusercontent.com/%s/%s/%s/%s" % (GITHUB_OWNER, GITHUB_REPO, GITHUB_BRANCH, quote(filename, safe="")), file=sys.stderr)
        elif not args.no_github and len(csv_bytes) > GITHUB_CONTENTS_SIZE_LIMIT_BYTES:
            print("  %s trop volumineux pour GitHub (%.0f Mo)." % (filename, size_mb), file=sys.stderr)

    # Feuille Google Sheets : envoi des données combinées (toutes professions sauf pharmacies, format standard)
    if not args.no_sheets and rows_for_sheets:
        creds_path = args.credentials
        if not creds_path or not Path(creds_path).exists():
            print("GOOGLE_APPLICATION_CREDENTIALS ou --credentials requis pour Sheets.", file=sys.stderr)
            sys.exit(1)
        sheet_rows = [OUT_CSV_HEADER] + rows_for_sheets
        upload_to_sheets(sheet_rows, creds_path)

    if args.no_github and files_pushed:
        print("CSV enregistrés dans : %s" % DEFAULT_OUTPUT_DIR, file=sys.stderr)
    print("Terminé.")


if __name__ == "__main__":
    main()
