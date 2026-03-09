import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

admin.initializeApp();

/** 2nd gen : RAM limitée + timeout court pour limiter les coûts. */
const callableOptions = { memory: "256MiB" as const, timeoutSeconds: 30 };

export const registerDevice = onCall(callableOptions, async (request) => {

  const auth = request.auth;

  if (!auth) {
    throw new HttpsError(
      "unauthenticated",
      "Not authenticated"
    );
  }

  const uid = auth.uid;

  const data = request.data;

  const deviceId: string | undefined = data?.deviceId;
  const deviceName: string | undefined = data?.deviceName;
  const appVersion: string | undefined = data?.appVersion;

  if (!deviceId || typeof deviceId !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "Missing or invalid deviceId"
    );
  }

  const db = admin.firestore();
  const userRef = db.collection("users").doc(uid);
  const deviceRef = userRef.collection("devices").doc(deviceId);

  await db.runTransaction(async (tx) => {

    const userSnap = await tx.get(userRef);

    if (!userSnap.exists) {
      throw new HttpsError(
        "not-found",
        "User not found"
      );
    }

    const userData = userSnap.data() || {};

    const email = auth.token?.email?.toLowerCase();
    const isAdmin = ADMIN_EMAILS.includes(email ?? "");
    const maxDevices: number = isAdmin ? 999 : (userData.maxDevices ?? 5);
    const currentCount: number = userData.devicesCount ?? 0;

    const deviceSnap = await tx.get(deviceRef);

    if (!deviceSnap.exists) {

      if (currentCount >= maxDevices) {
        throw new HttpsError(
          "permission-denied",
          "Maximum devices reached"
        );
      }

      tx.set(deviceRef, {
        deviceName: deviceName ?? "Unknown device",
        appVersion: appVersion ?? "unknown",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
        blacklisted: false,
      });

      tx.update(userRef, {
        devicesCount: currentCount + 1,
      });

    } else {

      tx.update(deviceRef, {
        lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
        appVersion: appVersion ?? deviceSnap.data()?.appVersion ?? "unknown",
      });
    }
  });

  return { success: true };
});

/** Emails exemptés de la limite de 5 appareils */
const ADMIN_EMAILS = ["offibox17@gmail.com", "offibox@gmail.com"];

export const getAdminUsers = onCall(callableOptions, async (request) => {
  const auth = request.auth;
  if (!auth || !ADMIN_EMAILS.includes(auth.token?.email?.toLowerCase() ?? "")) {
    throw new HttpsError("permission-denied", "Accès réservé à l'administrateur");
  }

  const db = admin.firestore();
  const usersSnap = await db.collection("users").get();

  const users: Array<{
    uid: string;
    email: string;
    plan: string;
    status: "active" | "expired" | "free";
    trialEndsAt: string | null;
    createdAt: string | null;
  }> = [];

  for (const doc of usersSnap.docs) {
    const d = doc.data();
    const trialEndsAt = d.trialEndsAt?.toDate?.();
    const plan = d.plan ?? "trial";
    let status: "active" | "expired" | "free" = "free";
    if (plan === "pro") status = "active";
    else if (trialEndsAt) {
      status = trialEndsAt > new Date() ? "free" : "expired";
    }

    users.push({
      uid: doc.id,
      email: d.email ?? "(sans email)",
      plan,
      status,
      trialEndsAt: trialEndsAt?.toISOString() ?? null,
      createdAt: d.createdAt?.toDate?.()?.toISOString() ?? null,
    });
  }

  users.sort((a, b) => (a.email ?? "").localeCompare(b.email ?? ""));

  return { users };
});

// Fax (Telnyx) — catalogue équipement CERP
export { sendCerpEquipmentFax } from "./fax";

// Export des fonctions email (emails.ts)
export {
  onUserFirstConnection,
  sendTrialEndEmails,
  sendIdeasEmail,
  sendIdeasEmailHttp,
  sendContactEmail,
} from "./emails";
