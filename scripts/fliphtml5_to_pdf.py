#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Usage:
  pip install playwright pypdf pillow img2pdf
  playwright install chromium
  python scripts/fliphtml5_to_pdf.py
  python scripts/fliphtml5_to_pdf.py -o catalogue_cerp_2025.pdf
  python scripts/fliphtml5_to_pdf.py --url "https://online.fliphtml5.com/smbsp/khzv/"
  python scripts/fliphtml5_to_pdf.py --method screenshot   # Méthode par capture d'écran (recommandée pour canvas)
  # Optionnel: OCR (rend le PDF "recherchable" si ocrmypdf+tesseract+ghostscript sont installés)
  python scripts/fliphtml5_to_pdf.py -o catalogue_cerp_2025_ocr.pdf --ocr --ocr-lang fra
"""

import argparse
import asyncio
import hashlib
import re
import shutil
import subprocess
import sys
from pathlib import Path

try:
    from playwright.async_api import async_playwright
except ImportError:
    print("Erreur: installez playwright avec: pip install playwright", file=sys.stderr)
    print("Puis: playwright install chromium", file=sys.stderr)
    sys.exit(1)

try:
    from pypdf import PdfWriter, PdfReader
except ImportError:
    PdfWriter = PdfReader = None

try:
    import img2pdf
    IMG2PDF_AVAILABLE = True
except ImportError:
    IMG2PDF_AVAILABLE = False

try:
    from PIL import Image
    import io
    PIL_AVAILABLE = True
except ImportError:
    PIL_AVAILABLE = False


DEFAULT_URL = "https://online.fliphtml5.com/smbsp/khzv/"
DEFAULT_OUTPUT = "Catalogue_Equipement_Cerp_2025.pdf"


def _images_to_pdf(image_paths: list, output_path: str) -> bool:
    """Convertit une liste d'images PNG en PDF. Utilise img2pdf (recommandé) ou pillow+pypdf."""
    if not image_paths:
        return False
    # Méthode 1 : img2pdf (simple et fiable)
    if IMG2PDF_AVAILABLE:
        try:
            with open(output_path, "wb") as f:
                f.write(img2pdf.convert([str(p) for p in image_paths]))
            return True
        except Exception as e:
            print(f"img2pdf échoué: {e}", file=sys.stderr)
    # Méthode 2 : pillow + pypdf
    if PIL_AVAILABLE and PdfWriter is not None and PdfReader is not None:
        try:
            writer = PdfWriter()
            for img_path in image_paths:
                img = Image.open(img_path).convert("RGB")
                img_bytes = io.BytesIO()
                img.save(img_bytes, format="PDF")
                img_bytes.seek(0)
                reader = PdfReader(img_bytes)
                writer.add_page(reader.pages[0])
            with open(output_path, "wb") as f:
                writer.write(f)
            return True
        except Exception as e:
            print(f"Pillow+pypdf échoué: {e}", file=sys.stderr)
    return False


async def _dismiss_cookiebot(page) -> None:
    """
    Cookiebot (Usercentrics) s'affiche parfois à chaque navigation (rechargement).
    On tente de l'accepter/masquer pour éviter qu'il occulte les captures.
    """
    # 1) Essayer les IDs connus Cookiebot (rapide)
    for selector in [
        "#CybotCookiebotDialogBodyButtonAccept",
        "#CybotCookiebotDialogBodyLevelButtonAccept",
        "button#CybotCookiebotDialogBodyButtonAccept",
        "button#CybotCookiebotDialogBodyLevelButtonAccept",
    ]:
        try:
            loc = page.locator(selector)
            if await loc.count():
                await loc.first.click(timeout=1200)
                await page.wait_for_timeout(250)
                return
        except Exception:
            pass

    # 2) Essayer via texte (FR/EN) sur la page et dans les frames
    patterns = [
        re.compile(r"allow all", re.I),
        re.compile(r"accept all", re.I),
        re.compile(r"tout accepter", re.I),
        re.compile(r"accepter tout", re.I),
        re.compile(r"accepter", re.I),
    ]

    async def _try_frame(frame) -> bool:
        for pat in patterns:
            try:
                btn = frame.get_by_role("button", name=pat)
                if await btn.count():
                    await btn.first.click(timeout=1200)
                    await page.wait_for_timeout(250)
                    return True
            except Exception:
                pass
        return False

    try:
        if await _try_frame(page):
            return
        for frame in page.frames:
            if frame == page.main_frame:
                continue
            if await _try_frame(frame):
                return
    except Exception:
        pass

    # 3) Fallback: masquer par CSS (si click impossible)
    try:
        await page.add_style_tag(
            content=(
                """
                #CybotCookiebotDialog,
                #CybotCookiebotDialogBodyUnderlay,
                #CybotCookiebotDialogBody,
                [id*="cookie"][id*="bot"],
                [class*="cookie"][class*="bot"],
                [class*="cookie"][class*="consent"],
                [id*="cookie"][id*="consent"] {
                  display: none !important;
                  visibility: hidden !important;
                  opacity: 0 !important;
                  pointer-events: none !important;
                }
                """
            )
        )
    except Exception:
        pass


def _cleanup_temp_outputs(out_dir: Path) -> None:
    for p in out_dir.glob("_page_*.png"):
        p.unlink(missing_ok=True)
    for p in out_dir.glob("_page_*.pdf"):
        p.unlink(missing_ok=True)


def _run_ocr_if_requested(pdf_path: str, ocr_enabled: bool, ocr_lang: str) -> str:
    """
    Si demandé et si disponible, lance ocrmypdf pour ajouter une couche texte (OCR).
    Retourne le chemin du PDF final (peut être inchangé si OCR non effectué).
    """
    if not ocr_enabled:
        return pdf_path

    exe = shutil.which("ocrmypdf")
    if not exe:
        print(
            "OCR demandé mais 'ocrmypdf' est introuvable dans le PATH.\n"
            "Installez ocrmypdf (et ses dépendances: tesseract + ghostscript), puis relancez.",
            file=sys.stderr,
        )
        return pdf_path

    in_path = Path(pdf_path)
    ocr_out = in_path.with_name(f"{in_path.stem}_ocr{in_path.suffix}")
    cmd = [
        exe,
        "--skip-text",
        "--optimize",
        "1",
        "--language",
        ocr_lang,
        str(in_path),
        str(ocr_out),
    ]
    try:
        print(f"\nOCR en cours ({ocr_lang})...")
        subprocess.run(cmd, check=True)
        return str(ocr_out)
    except Exception as e:
        print(f"OCR échoué: {e}", file=sys.stderr)
        return pdf_path


async def capture_flipbook_to_pdf(url: str, output_path: str, max_pages: int = 200, method: str = "screenshot") -> bool:
    """Ouvre le flipbook, navigue page par page et génère un PDF."""
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(
            viewport={"width": 1200, "height": 900},
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        )
        page = await context.new_page()

        try:
            print(f"Chargement de {url}...")
            # Toujours commencer sur #p=1 pour stabiliser le rendu
            base = url.split("#", 1)[0]
            start_url = f"{base}#p=1"
            await page.goto(start_url, wait_until="networkidle", timeout=60000)
            await asyncio.sleep(4)  # Laisser le flipbook s'initialiser

            out_dir = Path(output_path).parent
            _cleanup_temp_outputs(out_dir)
            pdf_files = []
            img_files = []
            last_hash = None
            same_in_a_row = 0

            # Une fois au début, accepter/masquer Cookiebot une bonne fois.
            await _dismiss_cookiebot(page)

            for i in range(max_pages):
                # Navigation: éviter les reloads (qui refont apparaître Cookiebot)
                page_num = i + 1
                if page_num > 1:
                    # Tenter le changement de hash (sans recharger)
                    try:
                        await page.evaluate("p => { window.location.hash = 'p=' + p; }", page_num)
                        await page.wait_for_timeout(1200)
                    except Exception:
                        # Fallback (moins bien): reload complet
                        await page.goto(
                            f"{base}#p={page_num}",
                            wait_until="networkidle",
                            timeout=60000,
                        )
                        await asyncio.sleep(2.0)

                # Si une bannière cookies revient, la retirer avant capture.
                await _dismiss_cookiebot(page)

                # Capturer la page courante (PDF ou screenshot selon la méthode)
                if method == "screenshot":
                    img_path = out_dir / f"_page_{i:04d}.png"
                    try:
                        await page.screenshot(path=str(img_path), full_page=False)
                    except Exception as e:
                        print(f"  Page {i}: erreur screenshot - {e}")
                        break
                    # Vérifier si l'image est vide ou identique
                    if img_path.stat().st_size < 1000:
                        img_path.unlink(missing_ok=True)
                        break
                    try:
                        page_bytes = img_path.read_bytes()
                        h = hashlib.md5(page_bytes).hexdigest()
                    except Exception:
                        # fallback: taille + nom, moins fiable
                        h = f"{img_path.stat().st_size}"
                    if h == last_hash:
                        same_in_a_row += 1
                    else:
                        same_in_a_row = 0
                    last_hash = h
                    # Si on voit trop de pages identiques d’affilée, on considère qu’on a dépassé la fin.
                    if same_in_a_row >= 4:
                        img_path.unlink(missing_ok=True)
                        print(f"  Page {i}: trop de pages identiques, fin.")
                        break
                    img_files.append(str(img_path))
                else:
                    pdf_path = out_dir / f"_page_{i:04d}.pdf"
                    try:
                        await page.pdf(path=str(pdf_path), format="A4", print_background=True)
                    except Exception as e:
                        print(f"  Page {i}: erreur PDF - {e}")
                        break
                    try:
                        page_bytes = Path(pdf_path).read_bytes()
                        h = hashlib.md5(page_bytes).hexdigest()
                    except Exception:
                        h = f"{Path(pdf_path).stat().st_size}"
                    if h == last_hash:
                        same_in_a_row += 1
                    else:
                        same_in_a_row = 0
                    last_hash = h
                    if same_in_a_row >= 4:
                        Path(pdf_path).unlink(missing_ok=True)
                        print(f"  Page {i}: trop de pages identiques, fin.")
                        break
                    pdf_files.append(str(pdf_path))

                print(f"  Page {i + 1} capturée")

            if method == "screenshot":
                if not img_files:
                    print("Aucune page capturée.")
                    return False
                if _images_to_pdf(img_files, output_path):
                    for f in img_files:
                        Path(f).unlink(missing_ok=True)
                    print(f"\nPDF généré: {output_path}")
                    return True
                print("Erreur: installez img2pdf pour convertir les images en PDF:")
                print("  pip install img2pdf")
                for f in img_files:
                    Path(f).unlink(missing_ok=True)
                return False

            if not pdf_files:
                print("Aucune page capturée.")
                return False

            # Fusionner les PDFs
            if len(pdf_files) == 1:
                Path(pdf_files[0]).rename(output_path)
            elif PdfWriter is not None and PdfReader is not None:
                try:
                    writer = PdfWriter()
                    for f in pdf_files:
                        reader = PdfReader(f)
                        for page_obj in reader.pages:
                            writer.add_page(page_obj)
                    with open(output_path, "wb") as out_f:
                        writer.write(out_f)
                finally:
                    for f in pdf_files:
                        Path(f).unlink(missing_ok=True)
            else:
                print("Installez pypdf pour fusionner: pip install pypdf")
                Path(pdf_files[0]).rename(output_path)
                for f in pdf_files[1:]:
                    Path(f).unlink(missing_ok=True)

            print(f"\nPDF généré: {output_path}")
            return True

        finally:
            await browser.close()


def main():
    parser = argparse.ArgumentParser(description="Convertit un flipbook FlipHTML5 en PDF")
    parser.add_argument("--url", default=DEFAULT_URL, help="URL du flipbook")
    parser.add_argument("-o", "--output", default=DEFAULT_OUTPUT, help="Fichier PDF de sortie")
    parser.add_argument("--max-pages", type=int, default=200, help="Nombre max de pages")
    parser.add_argument(
        "--method",
        choices=["screenshot", "pdf"],
        default="screenshot",
        help="screenshot = capture d'écran (recommandé pour canvas), pdf = pdf natif",
    )
    parser.add_argument(
        "--ocr",
        action="store_true",
        help="Ajoute une couche texte via OCR (nécessite ocrmypdf + tesseract + ghostscript)",
    )
    parser.add_argument("--ocr-lang", default="fra", help="Langue OCR (ex: fra, eng, deu...)")
    args = parser.parse_args()

    success = asyncio.run(capture_flipbook_to_pdf(args.url, args.output, args.max_pages, args.method))
    if success:
        final_path = _run_ocr_if_requested(args.output, args.ocr, args.ocr_lang)
        if final_path != args.output:
            print(f"PDF OCR généré: {final_path}")
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
