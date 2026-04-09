import { callClaude, parseJsonObject } from "./anthropic.ts";
import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

export type InsightCardJson = {
  id: string;
  type: "savings" | "health" | "productivity" | "habit";
  title: string;
  description: string;
  impactScore: number;
  actionButtonText: string;
  associatedData: Record<string, string>;
  priority: "low" | "medium" | "high" | "urgent";
};

export type InsightCardsResult = { insightCards: InsightCardJson[] };

const SYSTEM = `You are Optly, an AI life optimizer. Output ONLY valid JSON (no markdown) with this exact shape:
{
  "insightCards": [
    {
      "id": "<uuid v4>",
      "type": "savings" | "health" | "productivity" | "habit",
      "title": string,
      "description": string,
      "impactScore": 0-100,
      "actionButtonText": string,
      "associatedData": { "<key>": "<string value>", ... },
      "priority": "low" | "medium" | "high" | "urgent"
    }
  ]
}
Prioritize actionable, specific insights. Include 3-6 cards. associatedData values must be strings.`;

export async function fetchUserContextJson(
  admin: SupabaseClient,
  userId: string,
): Promise<Record<string, unknown>> {
  const { data, error } = await admin.rpc("get_user_context", { p_user_id: userId });
  if (error) throw new Error(error.message);
  return (data ?? {}) as Record<string, unknown>;
}

export async function generateInsightCards(
  context: Record<string, unknown>,
): Promise<InsightCardJson[]> {
  const userMsg = `User context JSON:\n${JSON.stringify(context, null, 2)}`;
  const raw = await callClaude({
    system: SYSTEM,
    messages: [{ role: "user", content: userMsg }],
    maxTokens: 4096,
  });
  const parsed = parseJsonObject<InsightCardsResult>(raw);
  if (!Array.isArray(parsed.insightCards)) {
    throw new Error("Invalid insightCards array from model");
  }
  return parsed.insightCards;
}

export async function persistInsightCards(
  admin: SupabaseClient,
  userId: string,
  cards: InsightCardJson[],
  replaceExisting: boolean,
): Promise<void> {
  if (replaceExisting) {
    await admin.from("insight_cards").delete().eq("user_id", userId);
  }
  if (cards.length === 0) return;
  const rows = cards.map((c) => ({
    id: c.id,
    user_id: userId,
    type: c.type,
    title: c.title,
    description: c.description,
    impact_score: Math.max(0, Math.min(100, Math.round(c.impactScore))),
    action_text: c.actionButtonText,
    priority: c.priority,
    associated_data: c.associatedData ?? {},
    acted_on: false,
  }));
  const { error } = await admin.from("insight_cards").upsert(rows, { onConflict: "id" });
  if (error) throw new Error(error.message);
}
