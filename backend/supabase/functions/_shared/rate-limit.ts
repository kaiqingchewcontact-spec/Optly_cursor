import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const DEFAULT_WINDOW_MS = 60 * 60 * 1000; // 1 hour
const DEFAULT_MAX = 20;

export async function checkInsightRateLimit(
  admin: SupabaseClient,
  userId: string,
  endpoint: string,
  maxInWindow = DEFAULT_MAX,
  windowMs = DEFAULT_WINDOW_MS,
): Promise<{ allowed: boolean; retryAfterSeconds?: number }> {
  const since = new Date(Date.now() - windowMs).toISOString();
  const { count, error } = await admin
    .from("insight_rate_limits")
    .select("*", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("endpoint", endpoint)
    .gte("created_at", since);

  if (error) throw new Error(`Rate limit check failed: ${error.message}`);
  const used = count ?? 0;
  if (used >= maxInWindow) {
    return { allowed: false, retryAfterSeconds: Math.ceil(windowMs / 1000) };
  }
  return { allowed: true };
}

export async function recordInsightRateLimit(
  admin: SupabaseClient,
  userId: string,
  endpoint: string,
): Promise<void> {
  const { error } = await admin.from("insight_rate_limits").insert({
    user_id: userId,
    endpoint,
  });
  if (error) throw new Error(`Rate limit record failed: ${error.message}`);
}
