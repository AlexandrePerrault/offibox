import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

/** Durée de validité du cache (24 h). */
const CACHE_TTL_HOURS = 24;

const FHIR_BASE = "https://gateway.api.esante.gouv.fr/fhir/v2";

/** Clé de cache : hash simple des paramètres de recherche. */
function cacheKey(params: {
  rpps?: string;
  structure?: string;
  nom?: string;
  prenom?: string;
  limit: number;
}): string {
  const parts = [
    "rpps:" + (params.rpps ?? "").trim(),
    "structure:" + (params.structure ?? "").trim(),
    "nom:" + (params.nom ?? "").trim(),
    "prenom:" + (params.prenom ?? "").trim(),
    "limit:" + params.limit,
  ];
  return parts.join("|");
}

/** Appel direct à l'API FHIR Annuaire Santé. */
async function callFhir(
  params: {
    rpps?: string;
    structure?: string;
    nom?: string;
    prenom?: string;
    limit: number;
  },
  apiKey: string
): Promise<string> {
  const limit = Math.min(50, Math.max(1, params.limit));
  const baseParams: Record<string, string> = {
    active: "true",
    _revinclude: "PractitionerRole:practitioner",
    _include: "PractitionerRole:organization",
    _count: String(limit),
  };

  let url: string;
  if (params.rpps && params.rpps.trim().length > 0) {
    const onlyDigits = params.rpps.replace(/\D/g, "");
    if (onlyDigits.length === 0) {
      return JSON.stringify({ resourceType: "Bundle", entry: [] });
    }
    const q = new URLSearchParams({ identifier: onlyDigits, ...baseParams });
    url = FHIR_BASE + "/Practitioner?" + q.toString();
  } else if (params.structure && params.structure.trim().length >= 2) {
    const q = new URLSearchParams({
      "name:contains": params.structure.trim(),
      ...baseParams,
    });
    url = FHIR_BASE + "/Organization?" + q.toString();
  } else if (params.nom && params.nom.trim().length > 0) {
    const q = new URLSearchParams(baseParams);
    q.set("name:family", params.nom.trim());
    if (params.prenom?.trim()) q.set("name:given", params.prenom.trim());
    url = FHIR_BASE + "/Practitioner?" + q.toString();
  } else {
    return JSON.stringify({ resourceType: "Bundle", entry: [] });
  }

  const res = await fetch(url, {
    headers: {
      "ESANTE-API-KEY": apiKey,
      Accept: "application/fhir+json",
    },
  });

  if (!res.ok) {
    throw new HttpsError("internal", "FHIR API error: " + res.status);
  }
  return res.text();
}

/**
 * Proxy + cache pour l'API FHIR Annuaire Santé.
 * Réduit la latence en servant les résultats depuis Firestore quand disponibles.
 */
export const searchAnnuairePS = onCall(
  { memory: "256MiB" as const, timeoutSeconds: 30 },
  async (request) => {
    const data = request.data as Record<string, unknown> | undefined;
    const rpps = typeof data?.rpps === "string" ? data.rpps : undefined;
    const structure = typeof data?.structure === "string" ? data.structure : undefined;
    const nom = typeof data?.nom === "string" ? data.nom : undefined;
    const prenom = typeof data?.prenom === "string" ? data.prenom : undefined;
    const limit = typeof data?.limit === "number" ? data.limit : 20;
    const apiKey = typeof data?.apiKey === "string" ? data.apiKey : "";

    if (!apiKey || apiKey.trim().length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "apiKey requis (ESANTE_API_KEY)"
      );
    }

    const params = { rpps, structure, nom, prenom, limit };
    const key = cacheKey(params);

    const db = admin.firestore();
    const docRef = db.collection("annuaire_ps_cache").doc(key);

    const docSnap = await docRef.get();
    const now = new Date();
    const expiresAt = new Date(now.getTime() + CACHE_TTL_HOURS * 60 * 60 * 1000);

    if (docSnap.exists) {
      const d = docSnap.data()!;
      const cachedExpires = d.expiresAt?.toDate?.();
      if (cachedExpires && cachedExpires > now) {
        return { body: d.body as string, cached: true };
      }
    }

    const body = await callFhir(params, apiKey);
    await docRef.set({
      body,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    });

    return { body, cached: false };
  }
);
