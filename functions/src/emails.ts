/**
 * Envoi d'emails Offibox (no-reply@offibox.fr)
 *
 * Option 1 - Extension Firebase "Trigger Email from Firestore" :
 *   Installez l'extension, configurez SMTP. Les docs créés dans `mail`
 *   sont envoyés automatiquement.
 *
 * Option 2 - Nodemailer (config via Firebase Secret Manager) :
 *   Définir les secrets OFFIBOX_SMTP_HOST, OFFIBOX_SMTP_USER, OFFIBOX_SMTP_PASS (voir README_EMAILS.md).
 */

import * as admin from "firebase-admin";
import { defineSecret } from "firebase-functions/params";
import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as nodemailer from "nodemailer";

/** Secrets SMTP (Firebase Secret Manager). Préfixe OFFIBOX_ pour éviter conflit avec d’éventuelles env vars SMTP_* sur Cloud Run. */
const smtpHost = defineSecret("OFFIBOX_SMTP_HOST");
const smtpUser = defineSecret("OFFIBOX_SMTP_USER");
const smtpPass = defineSecret("OFFIBOX_SMTP_PASS");

const emailSecrets = [smtpHost, smtpUser, smtpPass];

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

export type SmtpConfig = {
  host: string;
  port: number;
  user: string;
  pass: string;
  secure: boolean;
};

/** Envoi via nodemailer si config fournie (secrets) ou process.env (rétrocompat). */
async function sendWithNodemailer(
  to: string,
  subject: string,
  text: string,
  html: string | undefined,
  config?: SmtpConfig | null
): Promise<boolean> {
  const host = config?.host ?? process.env.OFFIBOX_SMTP_HOST ?? process.env.SMTP_HOST;
  const user = config?.user ?? process.env.OFFIBOX_SMTP_USER ?? process.env.SMTP_USER;
  const pass = config?.pass ?? process.env.OFFIBOX_SMTP_PASS ?? process.env.SMTP_PASS;
  const configured = !!(host && user && pass);
  console.log(`[sendEmail] SMTP configuré: ${configured} (host=${!!host}, user=${!!user}, pass=${!!pass})`);
  if (!host || !user || !pass) return false;

  const port = config?.port ?? parseInt(process.env.SMTP_PORT || "587", 10);
  const secure = config?.secure ?? process.env.SMTP_SECURE === "true";

  const transporter = nodemailer.createTransport({
    host,
    port,
    secure,
    auth: { user, pass },
  });

  await transporter.sendMail({
    from: `${FROM_NAME} <${FROM_EMAIL}>`,
    to,
    subject,
    text,
    html: html || undefined,
  });
  return true;
}

/** Envoi : Nodemailer (immédiat) si config SMTP, sinon Firestore "mail" (extension Trigger Email).
 *  smtpConfig : optionnel, fourni par les handlers quand les secrets sont définis.
 */
async function sendEmail(
  to: string,
  subject: string,
  text: string,
  html?: string,
  smtpConfig?: SmtpConfig | null
): Promise<"smtp" | "firestore"> {
  const sent = await sendWithNodemailer(to, subject, text, html, smtpConfig);
  if (sent) {
    console.log(`[sendEmail] Envoyé via SMTP vers ${to}`);
    return "smtp";
  }
  await createMailDoc(to, subject, text, html);
  console.log(`[sendEmail] Doc créé dans mail/ vers ${to} (envoi par extension Trigger Email si configurée)`);
  return "firestore";
}

/** Construit la config SMTP à partir des secrets (à appeler dans chaque handler qui envoie un email). */
function getSmtpConfigFromSecrets(): SmtpConfig | null {
  try {
    const host = smtpHost.value();
    const user = smtpUser.value();
    const pass = smtpPass.value();
    if (!host || !user || !pass) return null;
    return {
      host,
      user,
      pass,
      port: parseInt(process.env.SMTP_PORT || "587", 10),
      secure: process.env.SMTP_SECURE === "true",
    };
  } catch {
    return null;
  }
}

const IDEAS_RECIPIENT = "contact@offibox.fr";
const IDEAS_SUBJECT = "Boîte à idées";

/** Email de bienvenue (1ère connexion, essai 15 jours). onCreate ciblé = pas de surcoût onWrite. */
export const onUserFirstConnection = onDocumentCreated(
  { document: "users/{userId}", ...runOpts, secrets: emailSecrets },
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

    const smtp = getSmtpConfigFromSecrets();
    await sendEmail(email, subject, text, undefined, smtp);
  }
);

/** Envoi email fin d'essai (tous les jours à 8h) */
export const sendTrialEndEmails = onSchedule(
  { schedule: "0 8 * * *", timeZone: "Europe/Paris", ...runOpts, secrets: emailSecrets },
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

      const smtp = getSmtpConfigFromSecrets();
      await sendEmail(email, subject, text, undefined, smtp);
      await doc.ref.update({ trialEndEmailSent: true });
    }
  }
);

/** Envoi depuis la Boîte à idées (sans ouvrir le client mail) */
export const sendIdeasEmail = onCall(
  { ...runOpts, secrets: emailSecrets },
  async (request) => {
    const data = request.data as { message?: string; email?: string } | undefined;
    const message = typeof data?.message === "string" ? data.message.trim() : "";
    const contactEmail = typeof data?.email === "string" ? data.email.trim() : "";

    const text = [
      message || "(Aucun message)",
      contactEmail ? `Email du contact : ${contactEmail}` : "",
    ]
      .filter(Boolean)
      .join("\n\n");

    const smtp = getSmtpConfigFromSecrets();
    await sendEmail(IDEAS_RECIPIENT, IDEAS_SUBJECT, text, undefined, smtp);
    return { success: true };
  }
);

/** Boîte à idées — version HTTP pour clients desktop (Windows) où le callable n’est pas disponible.
 *  Destinataire : contact@offibox.fr (IDEAS_RECIPIENT).
 *  Pour que le mail parte vraiment : configurer SMTP (OFFIBOX_SMTP_*) ou l’extension Firestore "Trigger Email".
 */
export const sendIdeasEmailHttp = onRequest(
  { ...runOpts, secrets: emailSecrets },
  async (req, res) => {
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
    const smtp = getSmtpConfigFromSecrets();
    const delivery = await sendEmail(IDEAS_RECIPIENT, IDEAS_SUBJECT, text, undefined, smtp);
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
export const sendContactEmail = onCall(
  { ...runOpts, secrets: emailSecrets },
  async (request) => {
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

  const smtp = getSmtpConfigFromSecrets();
  const delivery = await sendEmail(IDEAS_RECIPIENT, subject, text, undefined, smtp);
  return { success: true, to: IDEAS_RECIPIENT, delivery };
});

/** URL vers laquelle rediriger l'utilisateur après avoir cliqué sur le lien (vérification ou réinitialisation). */
const AUTH_CONTINUE_URL = "https://www.offibox.fr/";

/**
 * Envoie un e-mail de vérification d'adresse en français (remplace le modèle Firebase en anglais).
 * À appeler après l'inscription au lieu de sendEmailVerification() côté client.
 * L'utilisateur doit être connecté (auth).
 */
export const sendVerificationEmailFr = onCall(
  { ...runOpts, secrets: emailSecrets },
  async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Utilisateur non connecté");
  }

  const email = auth.token?.email;
  if (!email || typeof email !== "string") {
    throw new HttpsError("invalid-argument", "Adresse e-mail non disponible");
  }

  const displayName = auth.token?.name ?? (auth.token?.email ?? "").split("@")[0];

  let link: string;
  try {
    link = await admin.auth().generateEmailVerificationLink(email, {
      url: AUTH_CONTINUE_URL,
      handleCodeInApp: false,
    });
  } catch (err) {
    console.error("generateEmailVerificationLink error:", err);
    throw new HttpsError("internal", "Impossible de générer le lien de vérification");
  }

  const subject = "Validez votre adresse e-mail pour Offibox";
  const text = `Bonjour ${displayName},

Cliquez sur le lien ci-dessous pour valider votre adresse e-mail et activer votre compte Offibox :

${link}

Si vous n'êtes pas à l'origine de cette demande, vous pouvez ignorer cet e-mail.

À bientôt,
L'équipe Offibox`;

  const html = `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family: sans-serif; line-height: 1.5; color: #334155;">
  <p>Bonjour ${escapeHtml(displayName)},</p>
  <p>Cliquez sur le lien ci-dessous pour valider votre adresse e-mail et activer votre compte Offibox :</p>
  <p><a href="${escapeHtml(link)}" style="color: #5A9094;">Valider mon adresse e-mail</a></p>
  <p style="font-size: 0.9em; color: #64748b;">Si le lien ne s'ouvre pas, copiez-collez cette adresse dans votre navigateur :<br><span style="word-break: break-all;">${escapeHtml(link)}</span></p>
  <p>Si vous n'êtes pas à l'origine de cette demande, vous pouvez ignorer cet e-mail.</p>
  <p>À bientôt,<br>L'équipe Offibox</p>
</body>
</html>`;

  const smtp = getSmtpConfigFromSecrets();
  const delivery = await sendEmail(email, subject, text, html, smtp);
  return { success: true, delivery };
});

/**
 * Envoie un e-mail de réinitialisation de mot de passe en français (lien « Définir le mot de passe »).
 * Utilisable après inscription ou pour « Mot de passe oublié ». Appelable sans être connecté en passant { email }.
 */
export const sendPasswordResetEmailFr = onCall(
  { ...runOpts, secrets: emailSecrets },
  async (request) => {
  const auth = request.auth;
  const data = (request.data as { email?: string } | undefined) ?? {};
  const email = (auth?.token?.email ?? data.email ?? "").toString().trim().toLowerCase();
  if (!email) {
    throw new HttpsError("invalid-argument", "Adresse e-mail requise");
  }

  let link: string;
  try {
    link = await admin.auth().generatePasswordResetLink(email, {
      url: AUTH_CONTINUE_URL,
      handleCodeInApp: false,
    });
  } catch (err) {
    console.error("generatePasswordResetLink error:", err);
    throw new HttpsError("internal", "Impossible de générer le lien");
  }

  const subject = "Définir votre mot de passe Offibox";
  const text = `Bonjour,

Vous avez demandé à définir ou réinitialiser votre mot de passe Offibox. Cliquez sur le lien ci-dessous :

${link}

Si vous n'êtes pas à l'origine de cette demande, vous pouvez ignorer cet e-mail. Le lien expirera sous 1 heure.

À bientôt,
L'équipe Offibox`;

  const html = `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family: sans-serif; line-height: 1.5; color: #334155;">
  <p>Bonjour,</p>
  <p>Vous avez demandé à définir ou réinitialiser votre mot de passe Offibox. Cliquez sur le lien ci-dessous :</p>
  <p><a href="${escapeHtml(link)}" style="color: #5A9094;">Définir mon mot de passe</a></p>
  <p style="font-size: 0.9em; color: #64748b;">Si le lien ne s'ouvre pas, copiez-collez cette adresse dans votre navigateur :<br><span style="word-break: break-all;">${escapeHtml(link)}</span></p>
  <p>Si vous n'êtes pas à l'origine de cette demande, vous pouvez ignorer cet e-mail. Le lien expirera sous 1 heure.</p>
  <p>À bientôt,<br>L'équipe Offibox</p>
</body>
</html>`;

  const smtp = getSmtpConfigFromSecrets();
  const delivery = await sendEmail(email, subject, text, html, smtp);
  return { success: true, delivery };
});

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}
