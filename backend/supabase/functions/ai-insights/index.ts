import { handleCors } from "../_shared/cors.ts";
import { errorResponse, jsonResponse } from "../_shared/responses.ts";
import { requireUser, serviceRoleClient } from "../_shared/auth.ts";
import {
  fetchUserContextJson,
  generateInsightCards,
  persistInsightCards,
} from "../_shared/insights.ts";
import { checkInsightRateLimit, recordInsightRateLimit } from "../_shared/rate-limit.ts";

type InsightsBody = {
  /** Optional client-provided context merged on top of DB snapshot */
  context?: Record<string, unknown>;
  /** When true, replace existing insight rows for this user */
  replaceExisting?: boolean;
};

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405, "method_not_allowed");
  }

  const auth = await requireUser(req);
  if (!auth.ok) return auth.response;

  let body: InsightsBody = {};
  try {
    if (req.headers.get("Content-Length") !== "0") {
      body = (await req.json()) as InsightsBody;
    }
  } catch {
    return errorResponse("Invalid JSON body", 400, "bad_request");
  }

  const admin = serviceRoleClient();

  try {
    const limit = await checkInsightRateLimit(admin, auth.user.id, "ai-insights");
    if (!limit.allowed) {
      return errorResponse("Rate limit exceeded", 429, "rate_limited", {
        retry_after_seconds: limit.retryAfterSeconds,
      });
    }

    const dbContext = await fetchUserContextJson(admin, auth.user.id);
    const merged: Record<string, unknown> = {
      ...dbContext,
      ...(body.context ?? {}),
      clientHints: body.context ?? {},
    };

    const cards = await generateInsightCards(merged);
    cards.sort((a, b) => b.impactScore - a.impactScore);

    await persistInsightCards(admin, auth.user.id, cards, body.replaceExisting === true);
    await recordInsightRateLimit(admin, auth.user.id, "ai-insights");

    return jsonResponse({ insightCards: cards });
  } catch (e) {
    console.error(e);
    return errorResponse(
      e instanceof Error ? e.message : "Insight generation failed",
      500,
      "insight_error",
    );
  }
});
