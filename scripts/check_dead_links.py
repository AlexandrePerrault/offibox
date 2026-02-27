#!/usr/bin/env python3
"""
Vérifie que toutes les URL trouvées dans le projet Offibox sont accessibles.
Si au moins une URL est morte, envoie un rapport par email.

Usage:
  python scripts/check_dead_links.py
  python scripts/check_dead_links.py --no-email   # affiche uniquement dans la console
  python scripts/check_dead_links.py --dry-run  # extrait les URL sans les tester

Planification à 6h du matin (Windows) : voir README_DEAD_LINKS.md
"""

import argparse
import os
import re
import smtplib
import sys
import time
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from urllib.parse import urlparse
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError

# Répertoire racine du projet (parent du dossier scripts, ou cwd si pubspec.yaml présent)
def _get_repo_root() -> str:
    script_dir = os.path.dirname(os.path.abspath(os.path.normpath(__file__)))
    candidate = os.path.dirname(script_dir)
    if os.path.isfile(os.path.join(candidate, "pubspec.yaml")):
        return candidate
    cwd = os.getcwd()
    if os.path.isfile(os.path.join(cwd, "pubspec.yaml")):
        return cwd
    return candidate


SCRIPT_DIR = os.path.dirname(os.path.abspath(os.path.normpath(__file__)))
REPO_ROOT = _get_repo_root()

# Dossiers à scanner
SCAN_DIRS = ["lib", "assets", "scripts", "windows", "linux", "macos", "android", "ios", "web"]
# Extensions de fichiers à scanner
SCAN_EXT = {
    ".dart", ".py", ".gs", ".yaml", ".yml", ".json", ".html", ".md", ".txt",
    ".csv", ".xml", ".kt", ".swift", ".gradle", ".plist",
}
# Dossiers à ignorer
SKIP_DIRS = {
    ".git", ".dart_tool", "build", "node_modules", ".idea", ".vscode",
    "Pods", "DerivedData", "gen", ".gradle",
}

# Regex pour extraire les URL (http ou https) — arrêt au blanc ou guillemet
URL_PATTERN = re.compile(
    r"https?://[^\s'\"]+",
    re.IGNORECASE,
)

# Fichiers à ne pas scanner (contiennent des URLs de démo / lockfile)
SKIP_FILES = {
    "pubspec.lock",  # URLs de packages, souvent 404 ou redirect
}

# Hôtes ou motifs d'URL à ignorer (exemples, templates, doc externe)
SKIP_URL_PATTERNS = (
    re.compile(r"^https?://(example\.com|domain\.tld|xyz|proxy|host\.name|host\.com|blahblah|rev|localhost)", re.I),
    re.compile(r"^https?://[^/]*\.\.\.", re.I),  # http://.../...
    re.compile(r"^https?://\s*$", re.I),  # vide
    re.compile(r"api\.github\.com/repos/\$|api\.github\.com/repos/\$\{|api\.github\.com/repos/\.\.\.", re.I),
    re.compile(r"brandfetch\.com/v2/brands/\{|brandfetch\.com/v2/brands/example", re.I),
    re.compile(r"docs\.google\.com/spreadsheets/d/XXXXX", re.I),
    re.compile(r"httpbin\.org", re.I),
    re.compile(r"oauth2\.googleapis\.com/token", re.I),
    re.compile(r"technet\.microsoft\.com", re.I),
    re.compile(r"twitter\.com", re.I),
    re.compile(r"article\.gmane\.org", re.I),
    re.compile(r"hg\.python\.org", re.I),
    re.compile(r"lxr\.mozilla\.org", re.I),
    re.compile(r"pypi\.org/project/feedparser", re.I),
    re.compile(r"pip\.pypa\.io", re.I),
    re.compile(r"setuptools\.pypa\.io", re.I),
    re.compile(r"peps\.python\.org", re.I),
    re.compile(r"docs\.python\.org", re.I),
    re.compile(r"specifications\.freedesktop\.org", re.I),
    re.compile(r"www\.unicode\.org/book", re.I),
    re.compile(r"learn\.microsoft\.com.*>`", re.I),
    re.compile(r"developer\.apple\.com/library", re.I),
    re.compile(r"static\.docs\.arm\.com", re.I),
    re.compile(r"urllib3\.readthedocs\.io", re.I),
    re.compile(r"requests\.readthedocs\.io", re.I),
    re.compile(r"facelessuser\.github\.io", re.I),
    re.compile(r"pyos\.github\.io", re.I),
    re.compile(r"www\.red-dove\.com", re.I),
    re.compile(r"www\.willmcgugan\.com", re.I),
    re.compile(r"foss\.heptapod\.net", re.I),
    re.compile(r"bitbucket\.org/pypa", re.I),
    re.compile(r"gist\.github\.com.*/[a-f0-9]+\.\.\.", re.I),
    re.compile(r"cloud\.google\.com/appengine", re.I),
    re.compile(r"developer\.android\.com/ndk", re.I),
    re.compile(r"pubs\.opengroup\.org", re.I),
    re.compile(r"www\.freedesktop\.org/software/systemd", re.I),
    re.compile(r"www\.cwi\.nl", re.I),
    re.compile(r"www\.zope\.com", re.I),
    re.compile(r"chardet\.feedparser\.org", re.I),
    re.compile(r"en\.wikipedia\.org/wiki/CRIME", re.I),
    re.compile(r"en\.wikipedia\.org/wiki/Binary_prefix", re.I),
    re.compile(r"android\.stackexchange\.com", re.I),
    re.compile(r"brew\.sh", re.I),
    re.compile(r"us-central1-\$", re.I),
    re.compile(r"x-access-token:\$\{\{", re.I),
)

# Destinataire du rapport
REPORT_EMAIL = "perraultalexandre78@gmail.com"

# Avec --only-project : ne vérifier que les URLs de ces domaines (liens vraiment utilisés par l'app / le site)
PROJECT_DOMAINS = (
    "ansm.sante.fr",
    "base-donnees-publique.medicaments.gouv.fr",
    "offibox.fr",
    "sante.gouv.fr",
    "ameli.fr",
    "lannuaire.service-public.gouv.fr",
    "medicaments.gouv.fr",
    "monespacepharmacien.viatris.com",
    "myris.viatris.fr",
    "service.viatris.fr",
    "omedit-fiches-cancer.fr",
    "omedit-idf.fr",
    "meddispar.fr",
    "pharmaradio.fr",
    "resopharma.fr",
    "ordre.pharmacien.fr",
    "e-pansement.fr",
    "splf.fr",
    "codage.ext.cnamts.fr",
    "github.com/AlexandrePerrault/offiboxdata",
    "raw.githubusercontent.com/AlexandrePerrault/offiboxdata",
    "signalement.social-sante.gouv.fr",
    "anses.fr",
)

# Timeout et politesse
REQUEST_TIMEOUT = 12
DELAY_BETWEEN_REQUESTS = 0.4


def should_skip(path: str) -> bool:
    rel = os.path.relpath(path, REPO_ROOT)
    parts = rel.split(os.sep)
    if any(p in SKIP_DIRS for p in parts):
        return True
    if parts[0] not in SCAN_DIRS and parts[0] != os.path.basename(REPO_ROOT):
        return False  # on est peut-être dans lib/ ou scripts/ déjà
    return False


def should_skip_url(url: str) -> bool:
    """Ignore les URLs exemples, templates ou invalides (ne pas les tester)."""
    # Placeholders / templates dans l'URL
    if "$" in url or "%s" in url or "%d" in url:
        return True
    if "{" in url or "}" in url:
        return True
    if "..." in url or ".." in url.split("/")[0]:  # host avec ...
        return True
    if "`" in url or ">" in url or "\\" in url.replace("\\/", ""):
        return True
    if re.search(r"\[\\\^", url):  # motif regex dans l'URL
        return True
    # Hôtes ou motifs connus (exemples, doc, templates)
    for pat in SKIP_URL_PATTERNS:
        if pat.search(url):
            return True
    # URL trop courte ou manifestement invalide
    try:
        parsed = urlparse(url)
        host = (parsed.netloc or "").split(":")[0]
        if not host or len(host) < 4:
            return True
        if host.startswith(".") or host in (".", "..", "...", "…"):
            return True
        # Éviter les URLs qui provoquent des erreurs idna (label empty, etc.)
        if host.replace(".", "").strip() == "":
            return True
    except Exception:
        return True
    return False


def collect_files(root: str | None = None) -> list[str]:
    base = root or REPO_ROOT
    files = []
    for scan_dir in SCAN_DIRS:
        full = os.path.join(base, scan_dir)
        if not os.path.isdir(full):
            continue
        for walk_root, dirs, filenames in os.walk(full):
            dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
            for name in filenames:
                ext = os.path.splitext(name)[1].lower()
                if ext in SCAN_EXT:
                    path = os.path.join(walk_root, name)
                    try:
                        rel = os.path.relpath(path, base)
                    except ValueError:
                        continue
                    parts = rel.split(os.sep)
                    if any(p in SKIP_DIRS for p in parts):
                        continue
                    if os.path.basename(path) in SKIP_FILES:
                        continue
                    files.append(path)
    # Fichiers à la racine
    try:
        for name in os.listdir(base):
            path = os.path.join(base, name)
            if os.path.isfile(path):
                ext = os.path.splitext(name)[1].lower()
                if ext in SCAN_EXT:
                    files.append(path)
    except OSError:
        pass
    return files


def extract_urls_from_file(filepath: str) -> list[tuple[str, str]]:
    """Retourne [(url, filepath), ...]."""
    try:
        with open(filepath, "r", encoding="utf-8", errors="replace") as f:
            text = f.read()
    except OSError:
        return []
    result = []
    for m in URL_PATTERN.finditer(text):
        url = m.group(0).rstrip(".,;:)")
        if not url.endswith("/"):
            url = url.rstrip(".,;:)")
        # Ignorer localhost, file, mailto, tel
        lower = url.lower()
        if "localhost" in lower or "127.0.0.1" in lower:
            continue
        if lower.startswith("file:") or "mailto:" in lower or "tel:" in lower:
            continue
        if should_skip_url(url):
            continue
        result.append((url, filepath))
    return result


def collect_all_urls(repo_root: str | None = None) -> dict[str, list[str]]:
    """Retourne { url: [fichier1, fichier2, ...] }. Si repo_root est fourni, utilise ce chemin comme racine."""
    global REPO_ROOT
    if repo_root is not None:
        prev, REPO_ROOT = REPO_ROOT, repo_root
    try:
        url_to_files = {}
        files = collect_files()
        for filepath in files:
            for url, fp in extract_urls_from_file(filepath):
                rel_path = os.path.relpath(fp, REPO_ROOT)
                if url not in url_to_files:
                    url_to_files[url] = []
                if rel_path not in url_to_files[url]:
                    url_to_files[url].append(rel_path)
        return url_to_files
    finally:
        if repo_root is not None:
            REPO_ROOT = prev


def check_url(url: str) -> tuple[bool, str]:
    """
    Vérifie si l'URL répond correctement (2xx ou 3xx redirection).
    Retourne (ok, message).
    """
    try:
        req = Request(
            url,
            headers={"User-Agent": "Offibox-DeadLinkCheck/1.0"},
            method="HEAD",
        )
        with urlopen(req, timeout=REQUEST_TIMEOUT) as r:
            code = r.getcode()
            if 200 <= code < 400:
                return True, str(code)
            return False, f"HTTP {code}"
    except HTTPError as e:
        return False, f"HTTP {e.code}"
    except URLError as e:
        try:
            req = Request(
                url,
                headers={"User-Agent": "Offibox-DeadLinkCheck/1.0"},
                method="GET",
            )
            with urlopen(req, timeout=REQUEST_TIMEOUT) as r:
                code = r.getcode()
                if 200 <= code < 400:
                    return True, str(code)
                return False, f"HTTP {code}"
        except Exception as e2:
            return False, str(e2)[:80]
    except Exception as e:
        return False, str(e)[:80]


def send_email(dead_list: list[tuple[str, str, list[str]]]) -> None:
    """Envoie le rapport par email via Gmail SMTP."""
    sender = os.environ.get("OFFIBOX_CHECK_EMAIL_SENDER") or os.environ.get("EMAIL_SENDER")
    password = os.environ.get("OFFIBOX_CHECK_EMAIL_APP_PASSWORD") or os.environ.get("EMAIL_APP_PASSWORD")
    if not sender or not password:
        print("Email non envoyé : définir OFFIBOX_CHECK_EMAIL_SENDER et OFFIBOX_CHECK_EMAIL_APP_PASSWORD (ou EMAIL_SENDER / EMAIL_APP_PASSWORD).", file=sys.stderr)
        return

    subject = f"[Offibox] {len(dead_list)} lien(s) mort(s) détecté(s)"
    body_lines = [
        "Bonjour,",
        "",
        f"Le contrôle des liens de l'application Offibox a détecté {len(dead_list)} URL inaccessible(s) :",
        "",
    ]
    for url, reason, files in dead_list:
        body_lines.append(f"  • {url}")
        body_lines.append(f"    Raison : {reason}")
        body_lines.append(f"    Fichiers : {', '.join(files[:5])}{' ...' if len(files) > 5 else ''}")
        body_lines.append("")
    body = "\n".join(body_lines)

    msg = MIMEMultipart()
    msg["From"] = sender
    msg["To"] = REPORT_EMAIL
    msg["Subject"] = subject
    msg.attach(MIMEText(body, "plain", "utf-8"))

    try:
        with smtplib.SMTP_SSL("smtp.gmail.com", 465) as smtp:
            smtp.login(sender, password)
            smtp.sendmail(sender, [REPORT_EMAIL], msg.as_string())
        print("Email envoyé à", REPORT_EMAIL)
    except Exception as e:
        print("Erreur envoi email :", e, file=sys.stderr)


def is_project_url(url: str) -> bool:
    """True si l'URL appartient à un domaine du projet (app / site Offibox)."""
    try:
        parsed = urlparse(url)
        host = parsed.netloc.split(":")[0].lower()
        path = (parsed.path or "").lower()
        for d in PROJECT_DOMAINS:
            if "/" in d:
                # ex. github.com/AlexandrePerrault/offiboxdata → vérifier host + path
                h, _, p = d.partition("/")
                if (h in host or host.endswith("." + h)) and p.lower() in path:
                    return True
            elif d in host or host.endswith("." + d):
                return True
        return False
    except Exception:
        return False


def main() -> int:
    parser = argparse.ArgumentParser(description="Vérifie les liens morts Offibox et envoie un rapport par email.")
    parser.add_argument("--no-email", action="store_true", help="Ne pas envoyer d'email, afficher uniquement.")
    parser.add_argument("--dry-run", action="store_true", help="Extraire les URL sans les tester.")
    parser.add_argument("--verbose", "-v", action="store_true", help="Afficher chaque URL testée.")
    parser.add_argument(
        "--only-project",
        action="store_true",
        help="Ne vérifier que les URLs du projet (ANSM, offiboxdata, offibox.fr, sante.gouv.fr, etc.).",
    )
    args = parser.parse_args()

    print("Scan des fichiers...")
    url_to_files = collect_all_urls()
    if args.only_project:
        url_to_files = {u: f for u, f in url_to_files.items() if is_project_url(u)}
        print("  (filtre --only-project : uniquement les URLs du projet)")
    urls = sorted(url_to_files.keys())
    if len(urls) == 0:
        cwd = os.getcwd()
        if os.path.isfile(os.path.join(cwd, "pubspec.yaml")):
            url_to_files = collect_all_urls(repo_root=cwd)
            urls = sorted(url_to_files.keys())
        if len(urls) == 0:
            n_files = len(collect_files())
            print(f"  (REPO_ROOT: {REPO_ROOT}, fichiers scannés: {n_files})")
            print("  Conseil: exécuter depuis la racine du projet: cd chemin\\vers\\offibox")
    print(f"  {len(urls)} URL uniques trouvées.")

    if args.dry_run:
        for u in urls:
            print(" ", u)
        return 0

    dead_list = []
    for i, url in enumerate(urls):
        if args.verbose:
            print(f"  [{i+1}/{len(urls)}] {url[:70]}...")
        ok, reason = check_url(url)
        if not ok:
            dead_list.append((url, reason, url_to_files[url]))
            print(f"  ❌ {url[:70]}... → {reason}")
        time.sleep(DELAY_BETWEEN_REQUESTS)

    if not dead_list:
        print("Aucun lien mort. Rien à signaler.")
        return 0

    print(f"\n{len(dead_list)} lien(s) mort(s).")
    if not args.no_email:
        send_email(dead_list)
    return 0


if __name__ == "__main__":
    sys.exit(main())
