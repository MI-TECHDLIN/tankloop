import {
  catalog,
  fingerprint,
  HandoverError,
  LIMITATION,
  MODEL,
  PROMPT_VERSION,
  providerRequest,
  uuid,
  validateSelection,
  validateSnapshot,
} from "./core.ts";

type Dependencies = {
  env: (name: string) => string | undefined;
  fetch: typeof fetch;
  now?: () => Date;
};
const headers = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, x-client-info, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store",
};
const unavailable = () =>
  new HandoverError(
    "unavailable",
    503,
    "Handover assistance is unavailable. Your field records and existing drafts are unchanged.",
  );
async function readJson(response: Response, limit = 100_000): Promise<unknown> {
  const reader = response.body?.getReader();
  if (!reader) throw unavailable();
  let length = 0;
  const chunks: Uint8Array[] = [];
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    length += value.length;
    if (length > limit) {
      await reader.cancel();
      throw unavailable();
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  return JSON.parse(new TextDecoder().decode(bytes));
}

export function createHandler(deps: Dependencies) {
  const now = deps.now ?? (() => new Date());
  return async (request: Request): Promise<Response> => {
    const reply = (body: unknown, status = 200) =>
      Response.json(body, { status, headers });
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers });
    }
    if (request.method !== "POST") {
      return reply({ code: "method", message: "Use POST." }, 405);
    }
    try {
      const authorization = request.headers.get("Authorization");
      if (!authorization?.match(/^Bearer \S+$/i)) {
        throw new HandoverError(
          "unauthorized",
          401,
          "Sign in again to prepare a handover.",
        );
      }
      const url = deps.env("SUPABASE_URL");
      const key = deps.env("SUPABASE_ANON_KEY");
      if (!url || !key) throw unavailable();
      const apiHeaders = {
        Authorization: authorization,
        apikey: key,
        "Content-Type": "application/json",
      };
      const auth = await deps.fetch(`${url}/auth/v1/user`, {
        headers: apiHeaders,
        signal: AbortSignal.timeout(5000),
      });
      if (!auth.ok) {
        throw new HandoverError(
          "unauthorized",
          401,
          "Sign in again to prepare a handover.",
        );
      }
      const user = await readJson(auth) as { id?: string };
      if (!user.id || !uuid.test(user.id)) {
        throw new HandoverError(
          "unauthorized",
          401,
          "Sign in again to prepare a handover.",
        );
      }
      let body;
      try {
        body = await readJson(new Response(request.body), 2048) as Record<
          string,
          unknown
        >;
      } catch {
        throw new HandoverError(
          "invalid_request",
          400,
          "Choose a point or case and try again.",
        );
      }
      if (
        !body || !["generate", "review"].includes(String(body.action)) ||
        !["point", "incident"].includes(String(body.kind)) ||
        typeof body.id !== "string" || !uuid.test(body.id) ||
        Object.keys(body).some((k) =>
          !["action", "kind", "id", "fingerprint", "generated_at", "reviewed"]
            .includes(k)
        )
      ) {
        throw new HandoverError(
          "invalid_request",
          400,
          "Choose a point or case and try again.",
        );
      }
      const load = async () => {
        const response = await deps.fetch(
          `${url}/rest/v1/rpc/handover_snapshot`,
          {
            method: "POST",
            headers: apiHeaders,
            body: JSON.stringify({ p_kind: body.kind, p_id: body.id }),
            signal: AbortSignal.timeout(8000),
          },
        );
        if (response.status === 401 || response.status === 403) {
          throw new HandoverError(
            "forbidden",
            403,
            "You no longer have access to these records. Return to your assignments.",
          );
        }
        if (!response.ok) throw unavailable();
        const snapshot = validateSnapshot(await readJson(response));
        if (snapshot.kind !== body.kind || snapshot.id !== body.id) {
          throw unavailable();
        }
        return snapshot;
      };
      const snapshot = await load();
      const hash = await fingerprint(snapshot);
      if (body.action === "review") {
        if (body.reviewed !== true) {
          throw new HandoverError(
            "review_required",
            400,
            "Review the wording and sources before saving.",
          );
        }
        const age = now().getTime() - Date.parse(String(body.generated_at));
        if (
          body.fingerprint !== hash || !Number.isFinite(age) || age < 0 ||
          age > 30 * 60_000
        ) {
          throw new HandoverError(
            "stale_sources",
            409,
            "The records changed or this draft expired. Keep your wording for reference and prepare a new draft, then review it again.",
          );
        }
        return reply({
          reviewer_id: user.id,
          reviewed_at: now().toISOString(),
          fingerprint: hash,
        });
      }
      const { facts, next_steps, gaps } = catalog(snapshot);
      if (!facts.length) {
        throw new HandoverError(
          "no_records",
          422,
          "There are no synced inspection, case, work or test records for this selection. Nothing has been inferred about the water.",
        );
      }
      const groqKey = deps.env("GROQ_API_KEY");
      if (!groqKey) {
        throw new HandoverError(
          "not_configured",
          503,
          "Handover assistance has not been configured. Continue your field work and try again later.",
        );
      }
      const response = await deps.fetch(
        "https://api.groq.com/openai/v1/chat/completions",
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${groqKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(providerRequest(facts)),
          signal: AbortSignal.timeout(20_000),
        },
      );
      if (response.status === 429) {
        throw new HandoverError(
          "rate_limited",
          429,
          "The assistant is busy. Wait a minute before trying again. Your draft is unchanged.",
        );
      }
      if (!response.ok) throw unavailable();
      const completion = await readJson(response) as {
        model?: string;
        choices?: {
          finish_reason: string;
          message: { content: string; refusal?: unknown };
        }[];
      };
      const choice = completion.choices?.[0];
      if (
        completion.model !== MODEL || !choice ||
        choice.finish_reason !== "stop" || choice.message.refusal
      ) throw unavailable();
      let highlights;
      try {
        highlights = validateSelection(
          JSON.parse(choice.message.content),
          facts,
        );
      } catch {
        throw new HandoverError(
          "invalid_output",
          502,
          "The AI draft did not match its sources. Try preparing it again.",
        );
      }
      // Recheck both authorization and records after the provider request.
      if (await fingerprint(await load()) !== hash) {
        throw new HandoverError(
          "stale_sources",
          409,
          "The records changed while preparing this draft. Prepare it again from the latest records.",
        );
      }
      return reply({
        version: 1,
        model: MODEL,
        prompt_version: PROMPT_VERSION,
        actor_id: user.id,
        generated_at: now().toISOString(),
        fingerprint: hash,
        snapshot,
        input_facts: facts,
        highlights,
        next_steps,
        gaps,
        limitation: LIMITATION,
        original_text: highlights.map((f) => f.text).join("\n\n"),
      });
    } catch (error) {
      if (error instanceof HandoverError) {
        return reply(
          { code: error.code, message: error.message },
          error.status,
        );
      }
      if (
        error instanceof Error &&
        ["TimeoutError", "AbortError"].includes(error.name)
      ) {
        return reply({
          code: "timeout",
          message:
            "The request timed out. Your wording is retained. Try again when connected.",
        }, 504);
      }
      // Never expose raw upstream responses, exception bodies, tokens or notes.
      return reply(
        { code: "unavailable", message: unavailable().message },
        503,
      );
    }
  };
}
