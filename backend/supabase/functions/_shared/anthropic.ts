const ANTHROPIC_VERSION = "2023-06-01";

export type ClaudeMessage = { role: "user" | "assistant"; content: string };

export async function callClaude(params: {
  system: string;
  messages: ClaudeMessage[];
  maxTokens?: number;
}): Promise<string> {
  const key = Deno.env.get("ANTHROPIC_API_KEY");
  if (!key) throw new Error("ANTHROPIC_API_KEY is not set");

  const model = Deno.env.get("ANTHROPIC_MODEL") ?? "claude-sonnet-4-20250514";

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": key,
      "anthropic-version": ANTHROPIC_VERSION,
    },
    body: JSON.stringify({
      model,
      max_tokens: params.maxTokens ?? 4096,
      system: params.system,
      messages: params.messages,
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Claude API error ${res.status}: ${text}`);
  }

  const data = (await res.json()) as {
    content: Array<{ type: string; text?: string }>;
  };
  const block = data.content?.find((c) => c.type === "text");
  if (!block?.text) throw new Error("Claude returned no text content");
  return block.text;
}

/** Extracts first JSON object from a model response (handles markdown fences). */
export function parseJsonObject<T>(raw: string): T {
  let s = raw.trim();
  const fence = s.match(/^```(?:json)?\s*([\s\S]*?)```$/m);
  if (fence) s = fence[1].trim();
  const start = s.indexOf("{");
  const end = s.lastIndexOf("}");
  if (start === -1 || end === -1 || end <= start) {
    throw new Error("No JSON object found in model output");
  }
  return JSON.parse(s.slice(start, end + 1)) as T;
}
