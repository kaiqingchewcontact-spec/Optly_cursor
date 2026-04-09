import { corsHeaders, handleCors } from "../_shared/cors.ts";
import { errorResponse, jsonResponse } from "../_shared/responses.ts";
import { requireUser, serviceRoleClient } from "../_shared/auth.ts";
import { callClaude, parseJsonObject } from "../_shared/anthropic.ts";

const CACHE_HOURS = 4;

type EnergyLevel = "low" | "moderate" | "high" | "peak";

type ScheduleBlockCategory =
  | "deepWork"
  | "health"
  | "finance"
  | "habits"
  | "rest";

type DailyBriefingJson = {
  id: string;
  date: string;
  greeting: string;
  priorityTasks: string[];
  healthInsights: string[];
  financeAlerts: string[];
  energyLevelPrediction: EnergyLevel;
  recommendedScheduleBlocks: Array<{
    id: string;
    title: string;
    start: string;
    end: string;
    category: ScheduleBlockCategory;
  }>;
};

function todayUtcDate(): string {
  return new Date().toISOString().slice(0, 10);
}

function fallbackBriefing(userId: string): DailyBriefingJson {
  const id = crypto.randomUUID();
  const day = todayUtcDate();
  const now = new Date();
  const end = new Date(now.getTime() + 60 * 60 * 1000);
  return {
    id,
    date: `${day}T00:00:00.000Z`,
    greeting: "Here is a quick plan for today while we reconnect to your full data.",
    priorityTasks: [
      "Review your top habit for today",
      "Take a 10-minute walk or stretch",
      "Skim upcoming renewals in subscriptions",
    ],
    healthInsights: [
      "Consistent sleep and movement still matter most for steady energy.",
    ],
    financeAlerts: [
      "When sync is back, Optly will surface subscription and savings opportunities.",
    ],
    energyLevelPrediction: "moderate",
    recommendedScheduleBlocks: [
      {
        id: crypto.randomUUID(),
        title: "Focused work block",
        start: now.toISOString(),
        end: end.toISOString(),
        category: "deepWork",
      },
      {
        id: crypto.randomUUID(),
        title: "Movement or recovery",
        start: end.toISOString(),
        end: new Date(end.getTime() + 15 * 60 * 1000).toISOString(),
        category: "health",
      },
    ],
  };
}

const BRIEFING_SYSTEM = `You are Optly's daily briefing engine. Output ONLY valid JSON (no markdown) matching this TypeScript-like shape:
{
  "id": "<uuid v4>",
  "date": "<ISO-8601 instant for the calendar day start UTC, e.g. 2026-04-09T00:00:00.000Z>",
  "greeting": string,
  "priorityTasks": string[],
  "healthInsights": string[],
  "financeAlerts": string[],
  "energyLevelPrediction": "low" | "moderate" | "high" | "peak",
  "recommendedScheduleBlocks": Array<{
    "id": "<uuid v4>",
    "title": string,
    "start": "<ISO-8601>",
    "end": "<ISO-8601>",
    "category": "deepWork" | "health" | "finance" | "habits" | "rest"
  }>
}
Use the provided user context. Be concise. 3-5 priority tasks. 2-4 schedule blocks for TODAY in local-feeling times but use ISO strings in UTC.`;

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  if (req.method !== "POST" && req.method !== "GET") {
    return errorResponse("Method not allowed", 405, "method_not_allowed");
  }

  const auth = await requireUser(req);
  if (!auth.ok) {
    const h = new Headers(auth.response.headers);
    Object.entries(corsHeaders).forEach(([k, v]) => h.set(k, v));
    return new Response(auth.response.body, { status: auth.response.status, headers: h });
  }

  const { user } = auth;
  const date = todayUtcDate();
  const admin = serviceRoleClient();

  try {
    const { data: cached, error: cacheErr } = await admin
      .from("daily_briefings")
      .select("content, cached_until")
      .eq("user_id", user.id)
      .eq("date", date)
      .maybeSingle();

    if (cacheErr) throw new Error(cacheErr.message);

    const now = Date.now();
    if (cached?.cached_until && cached?.content) {
      const until = new Date(cached.cached_until as string).getTime();
      if (!Number.isNaN(until) && until > now) {
        return jsonResponse({ briefing: cached.content, cached: true });
      }
    }

    const { data: ctx, error: ctxErr } = await admin.rpc("get_user_context", {
      p_user_id: user.id,
    });
    if (ctxErr) throw new Error(ctxErr.message);

    let briefing: DailyBriefingJson;
    try {
      const raw = await callClaude({
        system: BRIEFING_SYSTEM,
        messages: [
          {
            role: "user",
            content: `User id: ${user.id}\nContext JSON:\n${JSON.stringify(ctx, null, 2)}`,
          },
        ],
        maxTokens: 4096,
      });
      briefing = parseJsonObject<DailyBriefingJson>(raw);
    } catch {
      briefing = fallbackBriefing(user.id);
    }

    const cachedUntil = new Date(now + CACHE_HOURS * 60 * 60 * 1000).toISOString();
    const { error: upsertErr } = await admin.from("daily_briefings").upsert(
      {
        user_id: user.id,
        date,
        content: briefing as unknown as Record<string, unknown>,
        generated_at: new Date().toISOString(),
        cached_until: cachedUntil,
      },
      { onConflict: "user_id,date" },
    );
    if (upsertErr) {
      console.error("daily_briefing cache upsert:", upsertErr);
    }

    return jsonResponse({ briefing, cached: false });
  } catch (e) {
    console.error(e);
    const briefing = fallbackBriefing(user.id);
    return jsonResponse({
      briefing,
      cached: false,
      warning: "generated_fallback",
      message: e instanceof Error ? e.message : "Unknown error",
    });
  }
});
