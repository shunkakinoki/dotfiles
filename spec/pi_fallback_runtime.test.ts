import { expect, test } from "bun:test";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

async function runScenario(
  primary: string,
  failFree: boolean,
  retries: number,
  api = "openai-responses",
  alwaysFail = false,
  failureStatus = 504
) {
  const requests: string[] = [];
  const server = Bun.serve({
    hostname: "127.0.0.1",
    port: 0,
    async fetch(request) {
      const body = (await request.json()) as { model: string };
      requests.push(body.model);
      if (
        alwaysFail ||
        body.model !== "free" ||
        (failFree && requests.length === 1)
      ) {
        return new Response(null, { status: failureStatus });
      }
      if (api === "openai-responses") {
        const response = {
          id: "test",
          status: "completed",
          output: [
            {
              type: "message",
              id: "msg-test",
              role: "assistant",
              status: "completed",
              content: [{ type: "output_text", text: "OK", annotations: [] }]
            }
          ],
          usage: { input_tokens: 1, output_tokens: 1, total_tokens: 2 }
        };
        const events = [
          { type: "response.created", response: { id: "test" } },
          {
            type: "response.output_item.added",
            output_index: 0,
            item: {
              type: "message",
              id: "msg-test",
              role: "assistant",
              content: []
            }
          },
          {
            type: "response.content_part.added",
            output_index: 0,
            content_index: 0,
            part: { type: "output_text", text: "", annotations: [] }
          },
          {
            type: "response.output_text.delta",
            output_index: 0,
            content_index: 0,
            delta: "OK"
          },
          {
            type: "response.output_item.done",
            output_index: 0,
            item: response.output[0]
          },
          { type: "response.completed", response }
        ];
        return new Response(
          events.map((event) => `data: ${JSON.stringify(event)}\n\n`).join(""),
          { headers: { "content-type": "text/event-stream" } }
        );
      }
      const chunk = {
        id: "test",
        object: "chat.completion.chunk",
        created: 1,
        model: "free",
        choices: [
          {
            index: 0,
            delta: { role: "assistant", content: "OK" },
            finish_reason: null
          }
        ]
      };
      return new Response(
        `data: ${JSON.stringify(chunk)}\n\ndata: ${JSON.stringify({ ...chunk, choices: [{ index: 0, delta: {}, finish_reason: "stop" }] })}\n\ndata: [DONE]\n\n`,
        { headers: { "content-type": "text/event-stream" } }
      );
    }
  });
  const testHome = mkdtempSync(join(tmpdir(), "pi-runtime-"));
  try {
    const agent = join(testHome, ".pi", "agent");
    mkdirSync(agent, { recursive: true });
    writeFileSync(
      join(agent, "settings.json"),
      JSON.stringify({
        defaultProvider: "cliproxyapi",
        defaultModel: primary,
        retry: { enabled: retries > 0, maxRetries: retries, baseDelayMs: 1 },
        providerRetry: { maxRetries: 0 }
      })
    );
    writeFileSync(
      join(agent, "fallback.json"),
      JSON.stringify({ enabled: true, fallback_models: ["cliproxyapi/free"] })
    );
    writeFileSync(
      join(agent, "models.json"),
      JSON.stringify({
        providers: {
          cliproxyapi: {
            baseUrl: `http://127.0.0.1:${server.port}/v1`,
            apiKey: "test-dummy",
            api,
            models: ["primary", "free"].map((id) => ({
              id,
              reasoning: false,
              input: ["text"],
              contextWindow: 131072,
              maxTokens: 100
            }))
          }
        }
      })
    );
    const child = Bun.spawn(
      [
        process.execPath,
        resolve(
          "node_modules/@earendil-works/pi-coding-agent/dist/bundle/cli.js"
        ),
        "--offline",
        "--no-session",
        "--no-tools",
        "--no-extensions",
        "--no-skills",
        "--no-context-files",
        "-e",
        resolve("config/pi/fallback.ts"),
        "-p",
        "Reply OK"
      ],
      {
        cwd: testHome,
        env: { ...process.env, HOME: testHome, PI_CODING_AGENT_DIR: agent },
        stdout: "pipe",
        stderr: "pipe"
      }
    );
    const timer = setTimeout(() => child.kill(), 15000);
    try {
      const [stdout, stderr, status] = await Promise.all([
        new Response(child.stdout).text(),
        new Response(child.stderr).text(),
        child.exited
      ]);
      return { stdout, stderr, status, requests };
    } finally {
      clearTimeout(timer);
    }
  } finally {
    server.stop(true);
    rmSync(testHome, { recursive: true, force: true });
  }
}

test("a failed primary falls back to free and finishes the prompt", async () => {
  const result = await runScenario("primary", false, 0);
  expect(result.requests).toEqual(["primary", "free"]);
  expect(result.status).toBe(0);
  expect(result.stdout).toContain("OK");
}, 20000);

test("a transient failure on free retries free and finishes", async () => {
  const result = await runScenario("free", true, 1);
  expect(result.requests).toEqual(["free", "free"]);
  expect(result.status).toBe(0);
  expect(result.stdout).toContain("OK");
}, 20000);

test("completion API errors also fall back to free", async () => {
  const result = await runScenario("primary", false, 0, "openai-completions");
  expect(result.requests).toEqual(["primary", "free"]);
  expect(result.status).toBe(0);
  expect(result.stdout).toContain("OK");
}, 20000);

test("permanent free failure stops at the native retry budget", async () => {
  const result = await runScenario("free", true, 1, "openai-responses", true);
  expect(result.requests).toEqual(["free", "free"]);
  expect(result.status).toBe(1);
  expect(result.stderr).toContain("504");
}, 20000);

test("non-retryable primary errors do not trigger fallback", async () => {
  const result = await runScenario(
    "primary",
    false,
    0,
    "openai-responses",
    false,
    400
  );
  expect(result.requests).toEqual(["primary"]);
  expect(result.status).toBe(1);
}, 20000);

test("fallback cooperates with enabled native retries", async () => {
  const result = await runScenario("primary", false, 3);
  expect(result.requests).toEqual(["primary", "free"]);
  expect(result.status).toBe(0);
  expect(result.stdout).toContain("OK");
}, 20000);
