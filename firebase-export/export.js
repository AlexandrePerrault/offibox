const admin = require("firebase-admin");
const fs = require("fs");

admin.initializeApp({
  credential: admin.credential.cert(require("./serviceAccountKey.json")),
  storageBucket: "offibox-prod.firebasestorage.app"
});

const bucket = admin.storage().bucket();

async function exportUrls() {

  const prefix = "SANTRALIA-CATALOGUE 2025/";

  const [files] = await bucket.getFiles({
    prefix: prefix
  });

  const urls = files
    .filter(file => !file.name.endsWith("/"))
    .map(file => ({
      name: file.name.split("/").pop(),
      path: file.name,
      url: `https://storage.googleapis.com/${bucket.name}/${encodeURI(file.name)}`
    }));

  console.log("Nombre de fichiers trouvés :", urls.length);

  fs.writeFileSync(
    "santralia_catalogue_urls.json",
    JSON.stringify(urls, null, 2)
  );

  console.log("Fichier généré : santralia_catalogue_urls.json");
}

exportUrls().catch(console.error);