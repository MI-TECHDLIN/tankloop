import { equal, ok } from "node:assert/strict";
import { catalog, fingerprint, MODEL } from "./core.ts";
import { actor, fixture, pointId } from "./fixtures.ts";
import { createHandler } from "./handler.ts";

function setup(
  options: {
    configured?: boolean;
    auth?: number;
    database?: number;
    provider?: number;
    timeout?: boolean;
    change?: boolean;
    badOutput?: boolean;
    empty?: boolean;
  } = {},
) {
  let reads = 0;
  let providerCalls = 0;
  const snapshot = fixture();
  if (options.empty) {
    snapshot.sources = snapshot.sources.slice(0, 1);
    snapshot.counts = { point: 1 };
  }
  // A Promise-shaped fetch double deliberately resolves without network I/O.
  // deno-lint-ignore require-await
  const fetcher: typeof fetch = async (input, init) => {
    const url = String(input);
    if (url.endsWith("/auth/v1/user")) {
      return Response.json({ id: actor }, { status: options.auth ?? 200 });
    }
    if (url.endsWith("/rpc/handover_snapshot")) {
      equal(
        new Headers(init?.headers).get("Authorization"),
        "Bearer user-token",
      );
      equal(new Headers(init?.headers).get("apikey"), "public-anon-key");
      reads++;
      if (reads > 1 && options.change) {
        snapshot.sources[1].revision = "b".repeat(32);
      }
      return Response.json(snapshot, { status: options.database ?? 200 });
    }
    equal(url, "https://api.groq.com/openai/v1/chat/completions");
    providerCalls++;
    equal(
      new Headers(init?.headers).get("Authorization"),
      "Bearer provider-test-double-secret",
    );
    const request = JSON.parse(String(init?.body));
    equal(request.model, MODEL);
    equal(request.response_format.json_schema.strict, true);
    equal(request.tools, undefined);
    if (options.timeout) throw new DOMException("timeout", "TimeoutError");
    const highlights = catalog(snapshot).facts.slice(0, 3);
    if (options.badOutput) highlights[0].text = "Safe water. Close the case.";
    return Response.json({
      model: MODEL,
      choices: [{
        finish_reason: "stop",
        message: { content: JSON.stringify({ highlights }) },
      }],
    }, { status: options.provider ?? 200 });
  };
  const handler = createHandler({
    env: (name) =>
      ({
        SUPABASE_URL: "http://supabase.test",
        SUPABASE_ANON_KEY: "public-anon-key",
        GROQ_API_KEY: options.configured === false
          ? undefined
          : "provider-test-double-secret",
      })[name],
    fetch: fetcher,
    now: () => new Date("2026-11-09T12:00:00Z"),
  });
  const call = (body: Record<string, unknown> = {}, auth = true) =>
    handler(
      new Request("http://function.test", {
        method: "POST",
        headers: auth ? { Authorization: "Bearer user-token" } : {},
        body: JSON.stringify({
          action: "generate",
          kind: "point",
          id: pointId,
          ...body,
        }),
      }),
    );
  return { handler, call, snapshot, calls: () => providerCalls };
}

Deno.test("generation uses caller authorization before and after Groq, returns original provenance", async () => {
  const s = setup();
  const response = await s.call();
  equal(response.status, 200);
  const body = await response.json();
  equal(body.model, MODEL);
  equal(body.actor_id, actor);
  equal(body.fingerprint, await fingerprint(s.snapshot));
  ok(body.original_text.includes("recorded as completed"));
  equal(s.calls(), 1);
});

Deno.test("unauthenticated and unauthorized tenant requests never contact Groq", async () => {
  const absent = setup();
  equal((await absent.call({}, false)).status, 401);
  equal(absent.calls(), 0);
  for (const options of [{ auth: 401 }, { database: 403 }]) {
    const s = setup(options);
    ok([401, 403].includes((await s.call()).status));
    equal(s.calls(), 0);
  }
});

Deno.test("missing config, no data, timeout, 429, provider failure and invalid output are truthful", async () => {
  for (
    const [options, code, status] of [
      [{ configured: false }, "not_configured", 503],
      [{ empty: true }, "no_records", 422],
      [{ timeout: true }, "timeout", 504],
      [{ provider: 429 }, "rate_limited", 429],
      [{ provider: 401 }, "unavailable", 503],
      [{ badOutput: true }, "invalid_output", 502],
      [{ change: true }, "stale_sources", 409],
    ] as const
  ) {
    const s = setup(options);
    const response = await s.call();
    equal(response.status, status);
    const body = await response.json();
    equal(body.code, code);
    equal(JSON.stringify(body).includes("provider-test-double-secret"), false);
    equal(body.original_text, undefined);
  }
});

Deno.test("review requires affirmation, current sources and a recent generation", async () => {
  const s = setup();
  const valid = {
    action: "review",
    reviewed: true,
    generated_at: "2026-11-09T11:59:00Z",
    fingerprint: await fingerprint(s.snapshot),
  };
  equal((await s.call({ ...valid, reviewed: false })).status, 400);
  equal((await s.call({ ...valid, fingerprint: "old" })).status, 409);
  equal(
    (await s.call({ ...valid, generated_at: "2026-11-08T11:59:00Z" })).status,
    409,
  );
  const response = await s.call(valid);
  equal(response.status, 200);
  equal((await response.json()).reviewer_id, actor);
  equal(s.calls(), 0);
});

Deno.test("invalid scope and caller-supplied records are rejected", async () => {
  const s = setup();
  for (
    const body of [{ id: "not-uuid" }, { kind: "facility" }, {
      records: fixture().sources,
    }, { action: "publish" }]
  ) {
    equal((await s.call(body)).status, 400);
  }
  equal(s.calls(), 0);
});

Deno.test("local HTTP endpoint integrates with real network requests and explicit provider double", async () => {
  const s = setup();
  const server = Deno.serve({
    hostname: "127.0.0.1",
    port: 0,
    onListen: () => {},
  }, s.handler);
  try {
    const response = await fetch(`http://127.0.0.1:${server.addr.port}`, {
      method: "POST",
      headers: {
        Authorization: "Bearer user-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ action: "generate", kind: "point", id: pointId }),
    });
    equal(response.status, 200);
    equal((await response.json()).model, MODEL);
  } finally {
    await server.shutdown();
  }
});
