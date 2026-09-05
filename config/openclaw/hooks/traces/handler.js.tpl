import { spawn } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const AGENT_ID = "openclaw";
// The guard dedupes and caps the detached uploads `traces hook agent` starts.
const TRACES_HOOK_GUARD = path.join(
  os.homedir(),
  "dotfiles/config/shared/hooks/traces-agent-hook.sh"
);

const EVENT_MAP = {
  "agent:bootstrap": "session-start",
  "message:received": "prompt-submitted",
  "message:sent": "agent-done",
  "command:new": "session-end",
  "command:stop": "session-end",
};

const SESSION_ID_KEYS = [
  "sessionId",
  "session_id",
  "id",
  "traceId",
  "conversationId",
];
const PROMPT_KEYS = ["body", "content", "text", "prompt"];

function stateDir() {
  return process.env.OPENCLAW_STATE_DIR || path.join(os.homedir(), ".openclaw");
}

// The event payload shape is undocumented, so record every skip: a silent no-op
// would otherwise be indistinguishable from an idle gateway.
function debug(line) {
  try {
    fs.appendFileSync(
      path.join(stateDir(), "traces-hook.log"),
      `${new Date().toISOString()} ${line}\n`
    );
  } catch {}
}

function resolveTracesBin() {
  const candidates = [
    process.env.TRACES_BIN,
    path.join(os.homedir(), ".bun/install/global/node_modules/.bin/traces"),
    path.join(os.homedir(), ".local/bin/traces"),
  ].filter(Boolean);
  for (const candidate of candidates) {
    try {
      fs.accessSync(candidate, fs.constants.X_OK);
      return candidate;
    } catch {}
  }
  return "traces";
}

function firstString(sources, keys) {
  for (const source of sources) {
    if (!source || typeof source !== "object") continue;
    for (const key of keys) {
      const value = source[key];
      if (typeof value === "string" && value) return value;
    }
  }
  return "";
}

function resolveSessionId(event) {
  // The top-level sessionKey is a routing key ("agent:main:main"), not an id.
  return firstString(
    [event.context, event, event.context?.session],
    SESSION_ID_KEYS
  );
}

function resolveCwd(event) {
  const workspaceDir = firstString(
    [event.context, event],
    ["workspaceDir", "workspace", "cwd"]
  );
  return workspaceDir || path.join(stateDir(), "workspace");
}

export default function tracesHook(event) {
  const tracesEvent = EVENT_MAP[`${event.type}:${event.action}`];
  if (!tracesEvent) return;

  const sessionId = resolveSessionId(event);
  if (!sessionId) {
    const keys = Object.keys(event.context ?? {}).join(",");
    debug(
      `skip ${event.type}:${event.action} no-session-id context-keys=${keys}`
    );
    return;
  }

  const cwd = resolveCwd(event);
  if (!fs.existsSync(path.join(cwd, ".git"))) {
    debug(`skip ${event.type}:${event.action} not-a-git-repo cwd=${cwd}`);
    return;
  }

  // traces reads the destination namespace from the working directory, and the
  // gateway process runs from /tmp, so cwd has to be set explicitly.
  const child = spawn(
    TRACES_HOOK_GUARD,
    [tracesEvent, "--agent", AGENT_ID],
    {
      cwd,
      env: { ...process.env, TRACES_BIN: resolveTracesBin() },
      stdio: ["pipe", "ignore", "ignore"],
      detached: true,
    }
  );
  child.on("error", (error) => debug(`spawn failed: ${error.message}`));
  child.stdin.on("error", () => {});
  child.stdin.end(
    JSON.stringify({
      sessionKey: sessionId,
      sessionId,
      prompt: firstString([event.context], PROMPT_KEYS) || undefined,
    })
  );
  child.unref();
}
