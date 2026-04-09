import { createClient, type User } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { corsHeaders } from "./cors.ts";

export type AuthResult =
  | { ok: true; user: User; jwt: string }
  | { ok: false; response: Response };

/**
 * Verifies the JWT using Supabase Auth (anon key + Authorization header).
 */
export async function requireUser(req: Request): Promise<AuthResult> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return {
      ok: false,
      response: new Response(
        JSON.stringify({ error: "Missing or invalid Authorization header", code: "unauthorized" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      ),
    };
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) {
    return {
      ok: false,
      response: new Response(
        JSON.stringify({ error: "Server configuration error", code: "config" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      ),
    };
  }

  const jwt = authHeader.replace("Bearer ", "").trim();
  const supabase = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: { user }, error } = await supabase.auth.getUser(jwt);
  if (error || !user) {
    return {
      ok: false,
      response: new Response(
        JSON.stringify({
          error: error?.message ?? "Invalid or expired token",
          code: "unauthorized",
        }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      ),
    };
  }

  return { ok: true, user, jwt };
}

export function serviceRoleClient() {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY missing");
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
