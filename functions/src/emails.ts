/**
 * Envoi d'emails Offibox (no-reply@offibox.fr)
 *
 * Option 1 - Extension Firebase "Trigger Email from Firestore" :
 *   Installez l'extension, configurez SMTP. Les docs créés dans `mail`
 *   sont envoyés automatiquement.
 *
 * Option 2 - Nodemailer (config via variables d'environnement) :
 *   SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS
 */

import * as admin from "firebase-admin";
import { onCall, onRequest } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as nodemailer from "nodemailer";

/** Options runtime 2nd gen : RAM limitée + timeout court = moins cher. Pas de 1GB pour un email. */
const runOpts = { memory: "256MiB" as const, timeoutSeconds: 30 };

const FROM_EMAIL = "no-reply@offibox.fr";
const FROM_NAME = "Offibox";

/** Crée un doc dans la collection mail pour l'extension Trigger Email */
function createMailDoc(
  to: string,
  subject: string,
  text: string,
  html?: string
) {
  return admin.firestore().collection("mail").add({
    to,
    message: {
      subject,
      text,
      html: html || text.replace(/\n/g, "<br>"),
    },
    from: `${FROM_NAME} <${FROM_EMAIL}>`,
  });
}

/** Envoi via nodemailer si configuré */
async function sendWithNodemailer(
  to: string,
  subject: string,
  text: string
): Promise<boolean> {
  const host = process.env.SMTP_HOST;
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  const configured = !!(host && user && pass);
  console.log(`[sendEmail] SMTP configuré: ${configured} (host=${!!host}, user=${!!user}, pass=${!!pass})`);
  if (!host || !user || !pass) return false;

  const transporter = nodemailer.createTransport({
    host,
    port: parseInt(process.env.SMTP_PORT || "587", 10),
    secure: process.env.SMTP_SECURE === "true",
    auth: { user, pass },
  });

  await transporter.sendMail({
    from: `${FROM_NAME} <${FROM_EMAIL}>`,
    to,
    subject,
    text,
  });
  return true;
}

/** Envoi : Nodemailer (immédiat) ou Firestore "mail" (extension Trigger Email, délai possible 10s–1 min).
 *  Si SMTP non configuré et extension non installée → aucun mail ne part.
 */
async function sendEmail(to: string, subject: string, text: string): Promise<"smtp" | "firestore"> {
  const sent = await sendWithNodemailer(to, subject, text);
  if (sent) {
    console.log(`[sendEmail] Envoyé via SMTP vers ${to}`);
    return "smtp";
  }
  await createMailDoc(to, subject, text);
  console.log(`[sendEmail] Doc créé dans mail/ vers ${to} (envoi par extension Trigger Email si configurée)`);
  return "firestore";
}

const IDEAS_RECIPIENT = "contact@offibox.fr";
const IDEAS_SUBJECT = "Boîte à idées";

/** Email de bienvenue (1ère connexion, essai 15 jours). onCreate ciblé = pas de surcoût onWrite. */
export const onUserFirstConnection = onDocumentCreated(
  { document: "users/{userId}", ...runOpts },
  async (event) => {
    const after = event.data?.data();

    if (!after?.onboardingDone) return;

    const email = after.email as string | undefined;
    if (!email) return;

    const trialEndsAt = after.trialEndsAt?.toDate?.();
    const endStr = trialEndsAt
      ? trialEndsAt.toLocaleDateString("fr-FR", {
          day: "2-digit",
          month: "long",
          year: "numeric",
        })
      : "15 jours";

    const subject = "Bienvenue sur Offibox – Votre essai de 15 jours a commencé";
    const text = `Bonjour,

Vous êtes désormais connecté à Offibox.

Votre période d'essai gratuit de 15 jours a démarré. Elle se termine le ${endStr}.

Profitez de toutes les fonctionnalités pour découvrir la boîte à outils de l'officine.

À bientôt,
L'équipe Offibox`;

    await sendEmail(email, subject, text);
  }
);

/** Envoi email fin d'essai (tous les jours à 8h) */
export const sendTrialEndEmails = onSchedule(
  { schedule: "0 8 * * *", timeZone: "Europe/Paris", ...runOpts },
  async () => {
    const db = admin.firestore();
    const now = new Date();
    const usersSnap = await db.collection("users").get();

    for (const doc of usersSnap.docs) {
      const d = doc.data();
      if (d.plan === "pro") continue;
      if (d.trialEndEmailSent === true) continue;

      const trialEndsAt = d.trialEndsAt?.toDate?.();
      if (!trialEndsAt || trialEndsAt > now) continue;

      const email = d.email as string | undefined;
      if (!email) continue;

      const subject = "Votre période d'essai Offibox est terminée";
      const text = `Bonjour,

Votre période d'essai gratuit de 15 jours sur Offibox est désormais terminée.

Pour continuer à utiliser Offibox et accéder à toutes les fonctionnalités, souscrivez à notre offre à partir de 29,90 €/mois sur https://www.offibox.fr/

À bientôt,
L'équipe Offibox`;

      await sendEmail(email, subject, text);
      await doc.ref.update({ trialEndEmailSent: true });
    }
  }
);

/** Envoi depuis la Boîte à idées (sans ouvrir le client mail) */
export const sendIdeasEmail = onCall(runOpts, async (request) => {
  const data = request.data as { message?: string; email?: string } | undefined;
  const message = typeof data?.message === "string" ? data.message.trim() : "";
  const contactEmail = typeof data?.email === "string" ? data.email.trim() : "";

  const text = [
    message || "(Aucun message)",
    contactEmail ? `Email du contact : ${contactEmail}` : "",
  ]
    .filter(Boolean)
    .join("\n\n");

  await sendEmail(IDEAS_RECIPIENT, IDEAS_SUBJECT, text);
  return { success: true };
});

/** Boîte à idées — version HTTP pour clients desktop (Windows) où le callable n’est pas disponible.
 *  Destinataire : contact@offibox.fr (IDEAS_RECIPIENT).
 *  Pour que le mail parte vraiment : configurer SMTP (SMTP_HOST, SMTP_USER, SMTP_PASS) ou l’extension Firestore "Trigger Email".
 */
export const sendIdeasEmailHttp = onRequest(runOpts, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }
  let data: { message?: string; email?: string } = {};
  try {
    const body = req.body as Record<string, unknown> | undefined;
    data = (typeof body?.data === "object" ? body.data : body) as typeof data ?? {};
  } catch {
    // ignore
  }
  const message = typeof data.message === "string" ? data.message.trim() : "";
  const contactEmail = typeof data.email === "string" ? data.email.trim() : "";
  const text = [
    message || "(Aucun message)",
    contactEmail ? `Email du contact : ${contactEmail}` : "",
  ]
    .filter(Boolean)
    .join("\n\n");
  try {
    const delivery = await sendEmail(IDEAS_RECIPIENT, IDEAS_SUBJECT, text);
    // smtp = envoi immédiat ; firestore = extension envoie sous 10s–1 min (si installée)
    res.status(200).json({ success: true, to: IDEAS_RECIPIENT, delivery });
  } catch (err) {
    console.error("sendIdeasEmailHttp error:", err);
    res.status(500).json({
      error: "Envoi impossible",
      detail: err instanceof Error ? err.message : String(err),
      to: IDEAS_RECIPIENT,
    });
  }
});

/** Formulaire "Contact" (sans ouvrir Outlook / mailto) → envoie à contact@offibox.fr */
export const sendContactEmail = onCall(runOpts, async (request) => {
  const data = request.data as
    | {
        nom?: string;
        prenom?: string;
        email?: string;
        pharmacie?: string;
        telephone?: string;
        subject?: string;
        message?: string;
      }
    | undefined;

  const nom = typeof data?.nom === "string" ? data.nom.trim() : "";
  const prenom = typeof data?.prenom === "string" ? data.prenom.trim() : "";
  const email = typeof data?.email === "string" ? data.email.trim() : "";
  const pharmacie = typeof data?.pharmacie === "string" ? data.pharmacie.trim() : "";
  const telephone = typeof data?.telephone === "string" ? data.telephone.trim() : "";
  const subjectRaw = typeof data?.subject === "string" ? data.subject.trim() : "";
  const message = typeof data?.message === "string" ? data.message.trim() : "";

  if (!message) {
    return { success: false, error: "Message vide" };
  }

  const subject = subjectRaw ? `Contact Offibox — ${subjectRaw}` : "Contact Offibox";
  const text = [
    "Message reçu depuis le formulaire Contact (app Offibox).",
    "",
    nom ? `Nom : ${nom}` : "",
    prenom ? `Prénom : ${prenom}` : "",
    email ? `Mail : ${email}` : "",
    pharmacie ? `Pharmacie : ${pharmacie}` : "",
    telephone ? `Téléphone : ${telephone}` : "",
    request.auth?.uid ? `UID : ${request.auth.uid}` : "",
    request.auth?.token?.email ? `Compte : ${String(request.auth.token.email)}` : "",
    "",
    "—",
    message,
  ]
    .filter(Boolean)
    .join("\n");

  const delivery = await sendEmail(IDEAS_RECIPIENT, subject, text);
  return { success: true, to: IDEAS_RECIPIENT, delivery };
});
