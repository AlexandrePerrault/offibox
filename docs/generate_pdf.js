/**
 * Genere un PDF a partir de OFFIBOX_ARCHITECTURE_ET_SOURCES.html
 * Usage: node generate_pdf.js
 * Prerequis: npm install playwright
 */
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const htmlPath = path.join(__dirname, 'OFFIBOX_ARCHITECTURE_ET_SOURCES.html');
const pdfPath = path.join(__dirname, 'OFFIBOX_ARCHITECTURE_ET_SOURCES.pdf');

async function main() {
  const html = fs.readFileSync(htmlPath, 'utf-8');
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.setContent(html, { waitUntil: 'networkidle' });
  await page.pdf({
    path: pdfPath,
    format: 'A4',
    margin: { top: '20mm', right: '15mm', bottom: '20mm', left: '15mm' },
    printBackground: true,
  });
  await browser.close();
  console.log('PDF genere:', pdfPath);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
