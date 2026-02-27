import json
import re
import sys
import time
from urllib.parse import urljoin

import requests
from bs4 import BeautifulSoup

PAGE_URL = "https://sante.gouv.fr/professionnels/article/dgs-urgent"
BASE_URL = "https://sante.gouv.fr"
OUT_FILE = "latest_dgs_urgent.json"

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/121.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "fr-FR,fr;q=0.9,en;q=0.8",
}

def normalize_space(s: str) -> str:
    return re.sub(r"\s+", " ", s).strip()

def main():
    # ⏳ petite pause de politesse
    time.sleep(1.5)

    r = None

    for attempt in range(2):
        try:
            r = requests.get(
                PAGE_URL,
                headers=HEADERS,
                timeout=40
            )
            break
        except requests.exceptions.ReadTimeout:
            if attempt == 1:
                raise
            time.sleep(5)

    if r is None:
        print("❌ Impossible de récupérer la page")
        sys.exit(1)

    if r.status_code == 429:
        print("❌ 429 Too Many Requests – le site bloque temporairement.")
        sys.exit(1)

    r.raise_for_status()

    if not r.text or len(r.text) < 1000:
        print("❌ Réponse HTML invalide ou vide")
        sys.exit(1)

    soup = BeautifulSoup(r.text, "html.parser")

    candidates = []

    for a in soup.select("a[href$='.pdf']"):
        label = normalize_space(a.get_text(" ", strip=True))
        href = a.get("href", "")
        pdf_url = urljoin(BASE_URL, href)

        score = 0
        if "dgs" in label.lower():
            score += 10
        if "urgent" in label.lower():
            score += 5

        candidates.append((score, label, pdf_url))

    if not candidates:
        print("❌ Aucun DGS-Urgent trouvé")
        sys.exit(2)

    candidates.sort(key=lambda x: x[0], reverse=True)
    _, label, pdf_url = candidates[0]

    data = {
        "label": label,
        "pdf_url": pdf_url,
        "source": PAGE_URL,
    }

    with open(OUT_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print("✅ Dernier DGS-Urgent détecté :")
    print("   ", label)
    print("   ", pdf_url)

if __name__ == "__main__":
    main()
