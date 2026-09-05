import { expect, test } from "bun:test";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";

test("a 504 on free reports exhaustion through the event context", () => {
  const testHome = mkdtempSync(join(tmpdir(), "pi-fallback-"));
  try {
    const agentDir = join(testHome, ".pi", "agent");
    mkdirSync(agentDir, { recursive: true });
    writeFileSync(join(agentDir, "fallback.json"), JSON.stringify({
      enabled: true,
      fallback_models: ["cliproxyapi/free"],
    }));
    const result = spawnSync(process.execPath, ["-e", `
      import fallback from ${JSON.stringify(resolve("config/pi/fallback.ts"))};
      const handlers = new Map();
      const notices = [];
      fallback({
        on: (event, handler) => handlers.set(event, handler),
        setModel: () => { throw new Error("must stay on free"); },
        sendMessage: () => { throw new Error("must not retry indefinitely"); },
      });
      handlers.get("after_provider_response")({ status: 504 });
      await handlers.get("agent_end")({ messages: [{
        role: "assistant", stopReason: "error", errorMessage: "504 status code",
      }] }, {
        model: { provider: "cliproxyapi", id: "free" },
        ui: { notify: (message) => notices.push(message) },
        modelRegistry: { find: () => { throw new Error("no alternate model"); } },
      });
      if (notices.length !== 1 || !notices[0].includes("no fallback model available")) {
        throw new Error(JSON.stringify(notices));
      }
      notices.length = 0;
      handlers.get("before_provider_request")({});
      await handlers.get("agent_end")({ messages: [{
        role: "assistant", stopReason: "error", errorMessage: "400 invalid request",
      }] }, {
        model: { provider: "cliproxyapi", id: "free" },
        ui: { notify: (message) => notices.push(message) },
      });
      if (notices.length !== 0) throw new Error("stale status triggered fallback");
      console.log("exhaustion handled");
    `], { env: { ...process.env, HOME: testHome }, encoding: "utf8" });
    expect(result.stderr).toBe("");
    expect(result.status).toBe(0);
    expect(result.stdout).toContain("exhaustion handled");
  } finally {
    rmSync(testHome, { recursive: true, force: true });
  }
});
