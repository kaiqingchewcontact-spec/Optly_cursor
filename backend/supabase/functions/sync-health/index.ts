import { handleCors } from "../_shared/cors.ts";
import { errorResponse, jsonResponse } from "../_shared/responses.ts";
import { requireUser, serviceRoleClient } from "../_shared/auth.ts";
import {
  fetchUserContextJson,
  generateInsightCards,
  persistInsightCards,
} from "../_shared/insights.ts";

type HealthRowIn = {
  date: string;
  steps?: number | null;
  sleep_hours?: number | null;
  sleep_quality?: number | null;
  heart_rate_avg?: number | null;
  hrv?: number | null;
  active_energy?: number | null;
  energy_score?: number | null;
};

type SyncBody = {
  records?: HealthRowIn[];
};

function num(v: unknown): number | null {
  if (v === null || v === undefined) return null;
  const n = typeof v === "number" ? v : Number(v);
  return Number.isFinite(n) ? n : null;
}

function isSignificantChange(
  prev: Record<string, unknown> | null,
  next: Record<string, unknown>,
): boolean {
  if (!prev) return true;
  const keys = [
    "steps",
    "sleep_hours",
    "sleep_quality",
    "heart_rate_avg",
    "hrv",
    "active_energy",
    "energy_score",
  ] as const;
  for (const k of keys) {
    const a = num(prev[k]);
    const b = num(next[k]);
    if (a === null || b === null) continue;
    if (k === "steps" && Math.abs(a - b) >= 2000) return true;
    if (k === "sleep_hours" && Math.abs(a - b) >= 1.5) return true;
    if (
      (k === "sleep_quality" || k === "energy_score" || k === "heart_rate_avg" || k === "hrv") &&
      Math.abs(a - b) >= 15
    ) {
      return true;
    }
    if (k === "active_energy" && Math.abs(a - b) >= 250) return true;
  }
  return false;
}

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405, "method_not_allowed");
  }

  const auth = await requireUser(req);
  if (!auth.ok) return auth.response;

  let body: SyncBody;
  try {
    body = (await req.json()) as SyncBody;
  } catch {
    return errorResponse("Invalid JSON body", 400, "bad_request");
  }

  const records = Array.isArray(body.records) ? body.records : [];
  if (records.length === 0) {
    return errorResponse("records array is required", 400, "validation_error");
  }
  if (records.length > 90) {
    return errorResponse("Too many records in one batch (max 90)", 400, "validation_error");
  }

  const admin = serviceRoleClient();
  const upsertRows: Array<Record<string, unknown>> = [];
  let significant = false;

  for (const r of records) {
    if (!r?.date || typeof r.date !== "string") {
      return errorResponse("Each record needs a date (YYYY-MM-DD)", 400, "validation_error");
    }
    const date = r.date.slice(0, 10);

    const { data: existing } = await admin
      .from("health_data")
      .select(
        "steps, sleep_hours, sleep_quality, heart_rate_avg, hrv, active_energy, energy_score",
      )
      .eq("user_id", auth.user.id)
      .eq("date", date)
      .maybeSingle();

    const row = {
      user_id: auth.user.id,
      date,
      steps: r.steps ?? null,
      sleep_hours: r.sleep_hours ?? null,
      sleep_quality: r.sleep_quality ?? null,
      heart_rate_avg: r.heart_rate_avg ?? null,
      hrv: r.hrv ?? null,
      active_energy: r.active_energy ?? null,
      energy_score: r.energy_score ?? null,
    };

    if (isSignificantChange(existing as Record<string, unknown> | null, row)) {
      significant = true;
    }
    upsertRows.push(row);
  }

  const { error } = await admin.from("health_data").upsert(upsertRows, {
    onConflict: "user_id,date",
  });
  if (error) {
    return errorResponse("Failed to sync health data", 500, "db_error", error.message);
  }

  let insightsRegenerated = 0;
  if (significant) {
    try {
      const ctx = await fetchUserContextJson(admin, auth.user.id);
      const cards = await generateInsightCards({
        ...ctx,
        trigger: "health_sync_significant_change",
      });
      await persistInsightCards(admin, auth.user.id, cards, false);
      insightsRegenerated = cards.length;
    } catch (e) {
      console.error("insight regeneration after health sync failed:", e);
    }
  }

  return jsonResponse({
    ok: true,
    synced: upsertRows.length,
    significant_change: significant,
    insights_regenerated: insightsRegenerated,
  });
});
