#!/usr/bin/env python3
"""
Libère de l'espace sur GitHub en supprimant les artefacts des workflows Actions.

Usage:
  python scripts/delete_github_artifacts.py [--dry-run] [--keep-days N] [--repo owner/repo]

Variables d'environnement:
  GITHUB_TOKEN  - Token GitHub (PAT) avec scope repo. Requis.

Exemples:
  # Supprimer tous les artefacts (mode dry-run pour prévisualiser)
  python scripts/delete_github_artifacts.py --dry-run

  # Supprimer tous les artefacts
  GITHUB_TOKEN=ghp_xxx python scripts/delete_github_artifacts.py

  # Garder les artefacts des 7 derniers jours
  python scripts/delete_github_artifacts.py --keep-days 7

  # Cibler un autre repo
  python scripts/delete_github_artifacts.py --repo autre-owner/autre-repo
"""
import argparse
import os
import sys
from datetime import datetime, timezone, timedelta
from urllib.request import Request, urlopen
from urllib.error import HTTPError
import json

DEFAULT_REPO = "AlexandrePerrault/offibox"
API_BASE = "https://api.github.com"
USER_AGENT = "Offibox-DeleteArtifacts/1.0"


def parse_args():
    p = argparse.ArgumentParser(description="Supprime les artefacts GitHub Actions pour libérer de l'espace.")
    p.add_argument("--dry-run", action="store_true", help="Afficher sans supprimer")
    p.add_argument("--keep-days", type=int, default=0,
                   help="Garder les artefacts des N derniers jours (0 = tout supprimer)")
    p.add_argument("--name-contains", type=str, default="",
                   help="Ne supprimer que les artefacts dont le nom contient cette chaîne (ex: ios)")
    p.add_argument("--repo", default=DEFAULT_REPO, help=f"Repo owner/name (défaut: {DEFAULT_REPO})")
    return p.parse_args()


def api_request(token: str, method: str, url: str, data: dict | None = None) -> dict | None:
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": USER_AGENT,
    }
    body = json.dumps(data).encode() if data else None
    req = Request(url, data=body, headers=headers, method=method)
    try:
        with urlopen(req, timeout=30) as r:
            if method == "DELETE":
                return None
            return json.loads(r.read().decode())
    except HTTPError as e:
        if e.code == 204:
            return None
        raise


def list_artifacts(token: str, owner: str, repo: str) -> list[dict]:
    artifacts = []
    page = 1
    while True:
        url = f"{API_BASE}/repos/{owner}/{repo}/actions/artifacts?per_page=100&page={page}"
        resp = api_request(token, "GET", url)
        if not resp or "artifacts" not in resp:
            break
        batch = resp["artifacts"]
        if not batch:
            break
        artifacts.extend(batch)
        if len(batch) < 100:
            break
        page += 1
    return artifacts


def delete_artifact(token: str, owner: str, repo: str, artifact_id: int) -> bool:
    url = f"{API_BASE}/repos/{owner}/{repo}/actions/artifacts/{artifact_id}"
    try:
        api_request(token, "DELETE", url)
        return True
    except HTTPError:
        return False


def main():
    args = parse_args()
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if not token:
        print("Erreur: GITHUB_TOKEN ou GH_TOKEN requis.", file=sys.stderr)
        sys.exit(1)

    owner, _, repo = args.repo.partition("/")
    if not repo:
        print("Erreur: --repo doit être au format owner/repo", file=sys.stderr)
        sys.exit(1)

    cutoff = None
    if args.keep_days > 0:
        cutoff = datetime.now(timezone.utc) - timedelta(days=args.keep_days)

    print(f"Récupération des artefacts pour {owner}/{repo}...")
    artifacts = list_artifacts(token, owner, repo)

    if not artifacts:
        print("Aucun artefact trouvé.")
        return

    total_size = sum(a.get("size_in_bytes", 0) for a in artifacts)
    total_mb = total_size / (1024 * 1024)
    print(f"Total: {len(artifacts)} artefact(s), ~{total_mb:.1f} Mo")

    to_delete = []
    name_filter = (args.name_contains or "").lower()
    for a in artifacts:
        if name_filter and name_filter not in (a.get("name") or "").lower():
            continue
        created = datetime.fromisoformat(a["created_at"].replace("Z", "+00:00"))
        if cutoff and created >= cutoff:
            continue
        to_delete.append(a)

    if not to_delete:
        print("Aucun artefact à supprimer (tous dans la fenêtre --keep-days).")
        return

    size_to_free = sum(a.get("size_in_bytes", 0) for a in to_delete)
    print(f"À supprimer: {len(to_delete)} artefact(s), ~{size_to_free / (1024*1024):.1f} Mo")

    if args.dry_run:
        print("\n[DRY-RUN] Artefacts qui seraient supprimés:")
        for a in to_delete:
            print(f"  - {a['name']} (id={a['id']}, {a.get('size_in_bytes', 0) / 1024:.0f} Ko, {a['created_at']})")
        return

    deleted = 0
    for a in to_delete:
        if delete_artifact(token, owner, repo, a["id"]):
            deleted += 1
            print(f"  Supprimé: {a['name']} (id={a['id']})")
        else:
            print(f"  Échec: {a['name']} (id={a['id']})", file=sys.stderr)

    print(f"\n{deleted}/{len(to_delete)} artefact(s) supprimé(s).")


if __name__ == "__main__":
    main()
