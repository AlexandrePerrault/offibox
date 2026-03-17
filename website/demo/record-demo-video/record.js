const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const HTML_PATH = path.resolve(__dirname, '../demo-app-animation.html');
const OUTPUT_DIR = path.resolve(__dirname, '../');
const DURATION_MS = 90 * 1000; // 90 sec pour LinkedIn (1 cycle complet)

async function main() {
  console.log('Lancement Chromium...');
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1280, height: 720 },
    recordVideo: { dir: OUTPUT_DIR, size: { width: 1280, height: 720 } }
  });
  const page = await context.newPage();
  await page.goto('file://' + HTML_PATH, { waitUntil: 'networkidle', timeout: 30000 });
  console.log('Enregistrement', DURATION_MS/1000, 'sec...');
  await page.waitForTimeout(DURATION_MS);
  const video = page.video();
  await context.close();
  await browser.close();
  if (video) {
    const p = await video.path();
    const dest = path.join(OUTPUT_DIR, 'demo-offibox.webm');
    if (fs.existsSync(p)) fs.renameSync(p, dest);
    console.log('Video:', dest);
  }
}
main().catch(e => { console.error(e); process.exit(1); });
