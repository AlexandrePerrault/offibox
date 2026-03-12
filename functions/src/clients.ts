/**
 * Option B : stockage des données clients (inscription) en base via Cloud Function.
 * RGPD-friendly : données enregistrées côté serveur, pas en clair côté client.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

const callableOptions = { memory: "256MiB" as const, timeoutSeconds: 30 };

/** Emails admin (même liste que index.ts pour export CSV). */
const ADMIN_EMAILS = ["offibox17@gmail.com", "offibox@gmail.com"];

export type RegistrationData = {
  nom?: string;
  prenom?: string;
  profession?: string;
  professionOther?: string;
  pharmacy?: string;
  address?: string;
  zip?: string;
  city?: string;
  groupement?: string;
};

/**
 * Enregistre les données du formulaire d'inscription dans users/{uid}.
 * Appelée depuis la page d'inscription après signUpWithEmailPassword (utilisateur authentifié).
 */
export const saveRegistrationData = onCall(callableOptions, async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentification requise");
  }

  const uid = auth.uid;
  const email = (auth.token?.email as string | undefined) ?? "";
  const data = (request.data || {}) as RegistrationData;

  const nom = typeof data.nom === "string" ? data.nom.trim() : "";
  const prenom = typeof data.prenom === "string" ? data.prenom.trim() : "";
  const profession = typeof data.profession === "string" ? data.profession.trim() : "";
  const professionOther = typeof data.professionOther === "string" ? data.professionOther.trim() : "";
  const pharmacy = typeof data.pharmacy === "string" ? data.pharmacy.trim() : "";
  const address = typeof data.address === "string" ? data.address.trim() : "";
  const zip = typeof data.zip === "string" ? data.zip.trim() : "";
  const city = typeof data.city === "string" ? data.city.trim() : "";
  const groupement = typeof data.groupement === "string" ? data.groupement.trim() : "";

  const clientName = pharmacy || [prenom, nom].filter(Boolean).join(" ").trim() || email;

  const db = admin.firestore();
  const userRef = db.collection("users").doc(uid);

  await userRef.set(
    {
      email,
      clientName: clientName || email,
      nom: nom || null,
      prenom: prenom || null,
      profession: profession || null,
      professionOther: professionOther || null,
      pharmacy: pharmacy || null,
      address: address || null,
      zip: zip || null,
      city: city || null,
      groupement: groupement || null,
      registrationUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return { success: true };
});

/**
 * Exporte la liste des clients (users) en CSV. Réservé aux admins.
 * Retourne { csv: string } à enregistrer en fichier .csv.
 */
export const exportClientsCsv = onCall(
  { ...callableOptions, timeoutSeconds: 60 },
  async (request) => {
    const auth = request.auth;
    if (!auth || !ADMIN_EMAILS.includes((auth.token?.email as string)?.toLowerCase() ?? "")) {
      throw new HttpsError("permission-denied", "Accès réservé à l'administrateur");
    }

    const db = admin.firestore();
    const usersSnap = await db.collection("users").get();

    const headers = [
      "uid",
      "email",
      "clientName",
      "nom",
      "prenom",
      "profession",
      "professionOther",
      "pharmacy",
      "address",
      "zip",
      "city",
      "groupement",
      "plan",
      "trialEndsAt",
      "createdAt",
      "registrationUpdatedAt",
    ];

    function escapeCsvCell(value: string | number | null | undefined): string {
      if (value === null || value === undefined) return "";
      const s = String(value);
      if (s.includes(";") || s.includes('"') || s.includes("\n")) {
        return '"' + s.replace(/"/g, '""') + '"';
      }
      return s;
    }

    const rows: string[] = [headers.join(";")];

    for (const doc of usersSnap.docs) {
      const d = doc.data();
      const trialEndsAt = d.trialEndsAt?.toDate?.();
      const createdAt = d.createdAt?.toDate?.();
      const registrationUpdatedAt = d.registrationUpdatedAt?.toDate?.();

      rows.push(
        [
          doc.id,
          d.email ?? "",
          d.clientName ?? "",
          d.nom ?? "",
          d.prenom ?? "",
          d.profession ?? "",
          d.professionOther ?? "",
          d.pharmacy ?? "",
          d.address ?? "",
          d.zip ?? "",
          d.city ?? "",
          d.groupement ?? "",
          d.plan ?? "trial",
          trialEndsAt ? trialEndsAt.toISOString() : "",
          createdAt ? createdAt.toISOString() : "",
          registrationUpdatedAt ? registrationUpdatedAt.toISOString() : "",
        ].map(escapeCsvCell).join(";")
      );
    }

    const csv = "\uFEFF" + rows.join("\n");
    return { csv };
  }
);
