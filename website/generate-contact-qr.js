const fs = require('fs');
const path = require('path');
const QRCode = require('qrcode');

const logoPath = path.join(__dirname, 'logo-offibox.jpg');
const PHOTO_MAX_BYTES = 1600; // JPEG max pour tenir dans le QR (vCard totale ~3 Ko max)

function vCardText() {
  return [
    'BEGIN:VCARD',
    'VERSION:3.0',
    'FN:Alexandre Perrault',
    'N:Perrault;Alexandre;;;',
    'ORG:Offibox',
    'TEL;TYPE=CELL:0664418327',
    'EMAIL:contact@offibox.fr',
    'URL:https://www.offibox.fr',
    'END:VCARD'
  ].join('\r\n');
}

function buildVCardWithPhoto(photoBase64) {
  const lines = [
    'BEGIN:VCARD',
    'VERSION:3.0',
    'FN:Alexandre Perrault',
    'N:Perrault;Alexandre;;;',
    'ORG:Offibox',
    'TEL;TYPE=CELL:0664418327',
    'EMAIL:contact@offibox.fr',
    'URL:https://www.offibox.fr'
  ];
  const folded = (photoBase64.match(/.{1,76}/g) || []).join('\r\n ');
  lines.push('PHOTO;ENCODING=b;TYPE=JPEG:');
  lines.push(' ' + folded);
  lines.push('END:VCARD');
  return lines.join('\r\n');
}

async function getSmallLogoBase64() {
  if (!fs.existsSync(logoPath)) return null;
  try {
    const sharp = require('sharp');
    const targetSize = PHOTO_MAX_BYTES;
    for (const [size, quality] of [[64, 42], [56, 38], [48, 35], [40, 32], [32, 28]]) {
      const buf = await sharp(logoPath)
        .resize(size, size, { fit: 'cover' })
        .jpeg({ quality }).toBuffer();
      if (buf.length <= targetSize) return buf.toString('base64');
    }
    return null;
  } catch (e) {
    console.warn('Logo ignoré:', e.message, '- installez sharp avec: npm install sharp');
    return null;
  }
}

async function main() {
  const outPath = path.join(__dirname, 'contact-alexandre-perrault.png');
  const photoB64 = await getSmallLogoBase64();
  const vCard = photoB64 ? buildVCardWithPhoto(photoB64) : vCardText();
  if (photoB64) console.log('Logo inclus (miniature pour tenir dans le QR).');
  QRCode.toFile(outPath, vCard, { width: 280, margin: 2, errorCorrectionLevel: 'L' }, (err) => {
    if (err) {
      console.error(err);
      process.exit(1);
    }
    console.log('OK:', outPath);
  });
}

main();
