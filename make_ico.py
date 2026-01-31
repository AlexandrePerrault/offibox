from PIL import Image

src = "assets/icons/logo_offibox.png"   # adapte si besoin
dst = "windows/runner/resources/logo_offibox.ico"

img = Image.open(src).convert("RGBA")

sizes = [
    (16, 16),
    (32, 32),
    (48, 48),
    (256, 256),
]

img.save(dst, sizes=sizes)

print("✅ ICO généré :", dst)
