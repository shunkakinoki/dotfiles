import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { spawn } from "node:child_process";

function sendTraces(event: string, sessionId: string) {
  try {
    const child = spawn("traces", ["hook", "agent", event, "--agent", "pi"], {
      stdio: ["pipe", "ignore", "ignore"],
      detached: true,
    });
    // spawn ENOENT is async; the try/catch above cannot see it.
    child.on("error", () => {});
    child.stdin.end(JSON.stringify({ session_id: sessionId }));
    child.unref();
  } catch {
    // Hooks should never interrupt the user's Pi turn when Traces is absent.
  }
}

function sessionID(ctx: unknown): string {
  const manager = (ctx as { sessionManager?: { getSessionId?: () => unknown } })
    ?.sessionManager;
  const sid = manager?.getSessionId?.();
  return typeof sid === "string" ? sid : "";
}

export default function tracesPiHook(pi: ExtensionAPI): void {
  // Traces keys a session by Pi's own session id, so a turn is dropped rather
  // than filed under a guessed id.
  let session = "";

  function report(event: string, ctx: unknown) {
    session = sessionID(ctx) || session;
    if (session) sendTraces(event, session);
  }

  // Pi emits agent_end once per attempt from inside its retry/compaction loop,
  // but agent_settled once per prompt. Extensions cannot tell a retry from a
  // real ending, so prefer settled. agent_settled only exists from Pi 0.80.5,
  // and Pi's loader accepts a subscription to an unknown event without firing
  // it, so agent_end stays registered as the fallback for older Pi.
  let sawAgentSettled = false;

  pi.on("session_start", (_event, ctx) => {
    report("session-start", ctx);
  });

  pi.on("before_agent_start", (_event, ctx) => {
    report("prompt-submitted", ctx);
  });

  pi.on("agent_end", (_event, ctx) => {
    if (!sawAgentSettled) report("agent-done", ctx);
  });

  pi.on("agent_settled", (_event, ctx) => {
    sawAgentSettled = true;
    report("agent-done", ctx);
  });

  pi.on("session_shutdown", (_event, ctx) => {
    report("session-end", ctx);
    session = "";
  });
}
