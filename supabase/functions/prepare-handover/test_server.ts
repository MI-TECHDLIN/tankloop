// Opt-in SDK transport fixture. All Auth, database and provider responses are
// explicit test doubles over HTTP. No real secret or operational database used.
import { catalog, MODEL } from "./core.ts";
import { actor, fixture, pointId } from "./fixtures.ts";
import { createHandler } from "./handler.ts";

let baseUrl = "";
let stale = false;
const snapshot = fixture();
const handler = createHandler({
  env: (name) =>
    ({
      SUPABASE_URL: baseUrl,
      SUPABASE_ANON_KEY: "fixture-anon",
      GROQ_API_KEY: "fixture-provider",
    })[name],
  fetch: (input, init) =>
    fetch(
      String(input) === "https://api.groq.com/openai/v1/chat/completions"
        ? `${baseUrl}/provider-double`
        : input,
      init,
    ),
});
const server = Deno.serve({
  hostname: "127.0.0.1",
  port: 0,
  onListen: ({ port }) => {
    baseUrl = `http://127.0.0.1:${port}`;
    console.log(baseUrl);
  },
}, async (request) => {
  const path = new URL(request.url).pathname;
  if (path === "/functions/v1/prepare-handover") return handler(request);
  if (path === "/auth/v1/user") {
    return Response.json({ id: actor }, {
      status:
        request.headers.get("Authorization") === "Bearer fixture-user-token"
          ? 200
          : 401,
    });
  }
  if (path === "/rest/v1/rpc/handover_snapshot") {
    const body = await request.json();
    if (body.p_kind !== "point" || body.p_id !== pointId) {
      return Response.json({}, { status: 403 });
    }
    if (stale) snapshot.sources[1].revision = "b".repeat(32);
    return Response.json(snapshot);
  }
  if (path === "/provider-double") {
    return Response.json({
      model: MODEL,
      choices: [{
        finish_reason: "stop",
        message: {
          content: JSON.stringify({
            highlights: catalog(snapshot).facts.slice(0, 3),
          }),
        },
      }],
    });
  }
  if (path === "/change-source" && request.method === "POST") {
    stale = true;
    return Response.json({ changed: true });
  }
  return Response.json({}, { status: 404 });
});
Deno.addSignalListener("SIGTERM", () => {
  server.shutdown();
});
