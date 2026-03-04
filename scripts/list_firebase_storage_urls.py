#!/usr/bin/env python3
"""
Liste tous les fichiers d'un bucket Firebase Storage et extrait leurs URL.

Usage:
  python scripts/list_firebase_storage_urls.py --credentials serviceAccountKey.json
  python scripts/list_firebase_storage_urls.py --credentials key.json -o urls.txt
  python scripts/list_firebase_storage_urls.py --credentials key.json --prefix "SANTRALIA" --json -o urls.json

Nécessite: pip install firebase-admin
"""

import argparse
import json
import sys
from pathlib import Path
from urllib.parse import quote

try:
    import firebase_admin
    from firebase_admin import credentials, storage
except ImportError:
    print("Erreur: pip install firebase-admin", file=sys.stderr)
    sys.exit(1)

BUCKET = "offibox-prod.firebasestorage.app"
FIREBASE_DOWNLOAD_BASE = f"https://firebasestorage.googleapis.com/v0/b/{BUCKET}/o"


def blob_to_public_url(blob_name: str) -> str:
    """URL publique (storage.googleapis.com). Accès selon les règles du bucket."""
    encoded = quote(blob_name, safe="")
    return f"https://storage.googleapis.com/{BUCKET}/{encoded}"


def blob_to_firebase_download_url(blob_name: str, token: str) -> str:
    """URL Firebase avec token (lisible sans règles publiques). Comme celle fournie par la console Firebase."""
    encoded = quote(blob_name, safe="")
    return f"{FIREBASE_DOWNLOAD_BASE}/{encoded}?alt=media&token={token}"


def main() -> None:
    parser = argparse.ArgumentParser(description="Extrait toutes les URL des fichiers du bucket Firebase Storage.")
    parser.add_argument("--credentials", "-c", required=True, help="Chemin vers le JSON du compte de service Firebase")
    parser.add_argument("--prefix", "-p", default="", help="Préfixe des chemins (ex. SANTRALIA-CATALOGUE 2025)")
    parser.add_argument("-o", "--output", default="", help="Fichier de sortie (défaut: stdout)")
    parser.add_argument("--json", action="store_true", help="Sortie JSON (liste d'objets name, path, url)")
    parser.add_argument("--signed", action="store_true", help="Générer des URL signées (valides 7 jours) au lieu des URL publiques")
    parser.add_argument("--days", type=int, default=7, help="Validité des URL signées en jours (défaut: 7)")
    args = parser.parse_args()

    cred_path = Path(args.credentials)
    if not cred_path.is_file():
        print(f"Erreur: fichier introuvable: {cred_path}", file=sys.stderr)
        sys.exit(1)

    try:
        firebase_admin.get_app()
    except ValueError:
        firebase_admin.initialize_app(credentials.Certificate(str(cred_path)), {"storageBucket": BUCKET})

    bucket = storage.bucket()
    prefix = (args.prefix or "").strip()
    if prefix and not prefix.endswith("/"):
        prefix = prefix + "/"

    items = []
    expiration = __import__("datetime").timedelta(days=args.days) if args.signed else None

    for blob in bucket.list_blobs(prefix=prefix or None):
        name = blob.name
        url = None
        if not args.signed:
            try:
                blob.reload()
                token = (blob.metadata or {}).get("firebaseStorageDownloadTokens")
                if token:
                    url = blob_to_firebase_download_url(name, token)
            except Exception:
                pass
        if url is None:
            if args.signed:
                try:
                    url = blob.generate_signed_url(version="v4", expiration=expiration, method="GET")
                except Exception:
                    url = blob_to_public_url(name)
            else:
                url = blob_to_public_url(name)
        if args.json:
            items.append({"name": name.split("/")[-1], "path": name, "url": url})
        else:
            items.append(url)

    out = json.dumps(items, ensure_ascii=False, indent=2) if args.json else "\n".join(items)
    if args.output:
        Path(args.output).write_text(out, encoding="utf-8")
        print(f"{len(items)} URL écrites dans {args.output}", file=sys.stderr)
    else:
        print(out)


if __name__ == "__main__":
    main()
