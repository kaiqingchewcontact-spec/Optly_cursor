import { handleCors } from "../_shared/cors.ts";
import { errorResponse, jsonResponse } from "../_shared/responses.ts";
import { requireUser, serviceRoleClient } from "../_shared/auth.ts";

type PlaidAmount = { amount?: number; iso_currency_code?: string };

type PlaidStream = {
  stream_id?: string;
  merchant_name?: string;
  description?: string;
  name?: string;
  category?: string[];
  first_date?: string;
  last_date?: string;
  frequency?: string;
  average_amount?: PlaidAmount;
  last_amount?: PlaidAmount;
  status?: string;
  is_active?: boolean;
};

type ScanBody = {
  access_token?: string;
};

function plaidBaseUrl(): string {
  const env = (Deno.env.get("PLAID_ENV") ?? "sandbox").toLowerCase();
  if (env === "production") return "https://production.plaid.com";
  if (env === "development") return "https://development.plaid.com";
  return "https://sandbox.plaid.com";
}

function mapFrequencyToBillingCycle(freq: string | undefined): string {
  const f = (freq ?? "").toUpperCase();
  if (f.includes("WEEK")) return "weekly";
  if (f.includes("YEAR") || f.includes("ANNUAL")) return "annual";
  if (f.includes("QUARTER")) return "quarterly";
  return "monthly";
}

function monthlyEquivalent(amount: number, cycle: string): number {
  if (!Number.isFinite(amount) || amount <= 0) return 0;
  switch (cycle) {
    case "weekly":
      return amount * (52 / 12);
    case "quarterly":
      return amount / 3;
    case "annual":
      return amount / 12;
    default:
      return amount;
  }
}

function inferCategory(plaidCats: string[] | undefined): string {
  const c = (plaidCats ?? []).join(" ").toLowerCase();
  if (c.includes("software") || c.includes("productivity")) return "productivity";
  if (c.includes("entertainment") || c.includes("video") || c.includes("music")) {
    return "entertainment";
  }
  if (c.includes("gym") || c.includes("fitness") || c.includes("health")) return "health";
  if (c.includes("finance") || c.includes("bank")) return "finance";
  if (c.includes("education")) return "education";
  if (c.includes("utilit") || c.includes("telecom")) return "utilities";
  return "other";
}

function usageScoreFromStream(stream: PlaidStream): number {
  const last = stream.last_date ? new Date(stream.last_date) : null;
  const daysSince = last && !Number.isNaN(last.getTime())
    ? Math.max(0, Math.floor((Date.now() - last.getTime()) / (86400 * 1000)))
    : 90;

  const recency = Math.max(0, Math.min(100, 100 - daysSince * 1.5));
  const freq = (stream.frequency ?? "").toUpperCase();
  let freqPts = 15;
  if (freq.includes("WEEK")) freqPts = 25;
  else if (freq.includes("MONTH")) freqPts = 20;
  else if (freq.includes("YEAR") || freq.includes("ANNUAL")) freqPts = 10;

  const active = stream.status?.toUpperCase() === "ACTIVE" || stream.is_active !== false;
  const activePts = active ? 10 : -20;

  return Math.round(Math.max(0, Math.min(100, recency * 0.65 + freqPts + activePts)));
}

function recommendationFor(
  usage: number,
  monthlyCost: number,
): { ai: string; savings: number } {
  if (usage < 35 && monthlyCost > 0) {
    return { ai: "cancel", savings: monthlyCost };
  }
  if (usage < 55 && monthlyCost > 0) {
    return { ai: "downgrade", savings: Math.round(monthlyCost * 0.35 * 100) / 100 };
  }
  return { ai: "keep", savings: 0 };
}

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405, "method_not_allowed");
  }

  const auth = await requireUser(req);
  if (!auth.ok) return auth.response;

  let body: ScanBody;
  try {
    body = (await req.json()) as ScanBody;
  } catch {
    return errorResponse("Invalid JSON body", 400, "bad_request");
  }

  const accessToken = body.access_token?.trim();
  if (!accessToken) {
    return errorResponse("access_token is required", 400, "validation_error");
  }

  const clientId = Deno.env.get("PLAID_CLIENT_ID");
  const secret = Deno.env.get("PLAID_SECRET");
  if (!clientId || !secret) {
    return errorResponse("Plaid is not configured", 500, "config");
  }

  const plaidRes = await fetch(`${plaidBaseUrl()}/transactions/recurring/get`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      client_id: clientId,
      secret,
      access_token: accessToken,
    }),
  });

  if (!plaidRes.ok) {
    const text = await plaidRes.text();
    return errorResponse("Plaid request failed", 502, "plaid_error", {
      status: plaidRes.status,
      body: text.slice(0, 2000),
    });
  }

  const plaidData = (await plaidRes.json()) as {
    outflow_streams?: PlaidStream[];
    inflow_streams?: PlaidStream[];
  };

  const streams = [...(plaidData.outflow_streams ?? [])];
  const admin = serviceRoleClient();

  const rows: Array<Record<string, unknown>> = [];
  const scanItems: Array<{
    name: string;
    provider: string;
    billing_cycle: string;
    monthly_estimate: number;
    usage_score: number;
    ai_recommendation: string;
    potential_savings: number;
    last_date?: string;
  }> = [];

  let totalPotentialSavings = 0;

  for (const s of streams) {
    const name = (s.merchant_name || s.name || s.description || "Recurring charge").trim();
    const provider = (s.description || s.merchant_name || "unknown").slice(0, 200);
    const amount = Math.abs(
      s.average_amount?.amount ?? s.last_amount?.amount ?? 0,
    );
    const billing_cycle = mapFrequencyToBillingCycle(s.frequency);
    const monthly = monthlyEquivalent(amount, billing_cycle);
    const usage_score = usageScoreFromStream(s);
    const { ai, savings } = recommendationFor(usage_score, monthly);
    if (ai === "cancel" || ai === "downgrade") {
      totalPotentialSavings += savings;
    }

    const category = inferCategory(s.category);
    const last_used = s.last_date ? `${s.last_date}T12:00:00.000Z` : null;

    rows.push({
      user_id: auth.user.id,
      name,
      provider,
      cost: amount,
      billing_cycle,
      category,
      last_used,
      usage_score,
      ai_recommendation: ai,
      potential_savings: savings,
    });

    scanItems.push({
      name,
      provider,
      billing_cycle,
      monthly_estimate: Math.round(monthly * 100) / 100,
      usage_score,
      ai_recommendation: ai,
      potential_savings: Math.round(savings * 100) / 100,
      last_date: s.last_date,
    });
  }

  if (rows.length > 0) {
    const { error } = await admin.from("subscriptions").upsert(rows, {
      onConflict: "user_id,name,provider",
    });
    if (error) {
      return errorResponse("Failed to save subscriptions", 500, "db_error", error.message);
    }
  }

  return jsonResponse({
    scanned_count: scanItems.length,
    subscriptions: scanItems,
    total_potential_monthly_savings: Math.round(totalPotentialSavings * 100) / 100,
  });
});
