import { corsHeaders } from "./cors.ts";

export type ApiErrorBody = {
  error: string;
  code?: string;
  details?: unknown;
};

export function jsonResponse(
  body: unknown,
  status = 200,
  extraHeaders?: HeadersInit,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      ...Object.fromEntries(new Headers(extraHeaders ?? {}).entries()),
    },
  });
}

export function errorResponse(
  message: string,
  status: number,
  code?: string,
  details?: unknown,
): Response {
  const body: ApiErrorBody = { error: message };
  if (code) body.code = code;
  if (details !== undefined) body.details = details;
  return jsonResponse(body, status);
}
