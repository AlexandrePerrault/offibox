#!/usr/bin/env python3
# placeholder

Usage:
  pip install playwright pypdf pillow img2pdf
  playwright install chromium
  python scripts/fliphtml5_to_pdf.py
  python scripts/fliphtml5_to_pdf.py -o catalogue_cerp_2025.pdf
  python scripts/fliphtml5_to_pdf.py --url "https://online.fliphtml5.com/smbsp/khzv/"
  python scripts/fliphtml5_to_pdf.py --method screenshot   # Méthode par capture d'écran (recommandée pour canvas)
"""

import argparse
import asyncio
import sys
from pathlib import Path

try:
    from playwright.async_api import async_playwright
except ImportError:
    print("Erreur: installez playwright avec: pip install playwright", file=sys.stderr)
    print("Puis: playwright install chromium", file=sys.stderr)
    sys.exit(1)

try:
    from pypdf import PdfWriter, PdfReader, PdfMerger
except ImportError:
    PdfWriter = PdfReader = PdfMerger = None

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
            await page.goto(url, wait_until="networkidle", timeout=60000)
            await asyncio.sleep(4)  # Laisser le flipbook s'initialiser

            out_dir = Path(output_path).parent
            pdf_files = []
            img_files = []
            seen_hashes = set()

            for i in range(max_pages):
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
                    img_files.append(str(img_path))
                else:
                    pdf_path = out_dir / f"_page_{i:04d}.pdf"
                    try:
                        await page.pdf(path=str(pdf_path), format="A4", print_background=True)
                    except Exception as e:
                        print(f"  Page {i}: erreur PDF - {e}")
                        break
                    pdf_files.append(str(pdf_path))

                # Vérifier si le contenu a changé (éviter boucle infinie)
                content = await page.content()
                h = hash(content[:8000])
                if h in seen_hashes:
                    if method == "screenshot" and img_files:
                        Path(img_files[-1]).unlink(missing_ok=True)
                        img_files.pop()
                    elif pdf_files:
                        Path(pdf_files[-1]).unlink(missing_ok=True)
                        pdf_files.pop()
                    print(f"  Page {i}: contenu identique, fin.")
                    break
                seen_hashes.add(h)

                print(f"  Page {i + 1} capturée")

                # Navigation vers la page suivante
                # 1. Clic dans l'iframe pour le focus, puis flèche droite (FlipHTML5)
                for frame in page.frames:
                    if frame != page.main_frame:
                        try:
                            await frame.click("body", position={"x": 500, "y": 400})
                            await asyncio.sleep(0.3)
                            break
                        except Exception:
                            continue
                await page.keyboard.press("ArrowRight")
                await asyncio.sleep(1.5)

                # 2. Clic à droite (zone "page suivante" des flipbooks)
                box = page.viewport_size
                if box:
                    await page.mouse.click(box["width"] - 60, box["height"] // 2)
                    await asyncio.sleep(1.2)

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
            elif PdfMerger is not None:
                merger = PdfMerger()
                for f in pdf_files:
                    merger.append(f)
                merger.write(output_path)
                merger.close()
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
    args = parser.parse_args()

    success = asyncio.run(capture_flipbook_to_pdf(args.url, args.output, args.max_pages, args.method))
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
