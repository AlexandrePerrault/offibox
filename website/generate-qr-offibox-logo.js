/**
 * Génère un QR code pointant vers https://www.offibox.fr avec le logo au centre.
 * Dépendances : qrcode, sharp
 * Logo attendu : website/logo sans texte.png (ou chemin ci-dessous)
 */
const fs = require('fs');
const path = require('path');
const QRCode = require('qrcode');
const sharp = require('sharp');

const TARGET_URL = 'https://www.offibox.fr';
const QR_SIZE = 500;
const LOGO_SIZE = 100; // côté du logo au centre (~20 % du QR)
const OUT_PATH = path.join(__dirname, 'offibox-qrcode-logo.png');

const logoPaths = [
  path.join(__dirname, 'logo sans texte.png'),
  path.join(__dirname, 'logo-sans-texte.png'),
];

async function main() {
  const logoPath = logoPaths.find(p => fs.existsSync(p));
  if (!logoPath) {
    console.error('Logo introuvable. Placez "logo sans texte.png" dans le dossier website.');
    process.exit(1);
  }

  return new Promise((resolve, reject) => {
    QRCode.toDataURL(TARGET_URL, {
      errorCorrectionLevel: 'H',
      width: QR_SIZE,
      margin: 2,
      color: { dark: '#000000', light: '#ffffff' },
    }, async (err, dataUrl) => {
      if (err) {
        reject(err);
        return;
      }
      try {
        const base64 = dataUrl.replace(/^data:image\/\w+;base64,/, '');
        const qrBuffer = Buffer.from(base64, 'base64');

        const logoResized = await sharp(logoPath)
          .resize(LOGO_SIZE, LOGO_SIZE, { fit: 'contain', background: { r: 255, g: 255, b: 255, alpha: 1 } })
          .png()
          .toBuffer();

        const left = Math.round((QR_SIZE - LOGO_SIZE) / 2);
        const top = Math.round((QR_SIZE - LOGO_SIZE) / 2);

        const outBuffer = await sharp(qrBuffer)
          .composite([{ input: logoResized, left, top }])
          .png()
          .toBuffer();

        fs.writeFileSync(OUT_PATH, outBuffer);
        console.log('OK:', OUT_PATH);
        resolve();
      } catch (e) {
        reject(e);
      }
    });
  });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
