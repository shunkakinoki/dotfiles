// Runs the Claude-style PreToolUse hooks in hooks.json before OpenCode tool
// calls, for both the 1.x `server` and the 2.x `setup` plugin APIs.
// A hook that exits 2, times out, or cannot run rejects the call.
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

type Hook = { type?: string; command?: string; timeout?: number };
type Entry = { matcher?: string; hooks?: Hook[] };

const DEFAULT_TIMEOUT_MS = 60_000;

function hooksFile(): string {
  const base = process.env.XDG_CONFIG_HOME || join(homedir(), ".config");
  return join(base, "opencode", "hooks.json");
}

function preToolUse(): Entry[] {
  const file = hooksFile();
  if (!existsSync(file)) return [];
  const parsed = JSON.parse(readFileSync(file, "utf8")) as {
    hooks?: { PreToolUse?: Entry[] };
  };
  return parsed.hooks?.PreToolUse ?? [];
}

// OpenCode 2.x names the shell tool `shell`; hooks.json matchers and the
// shared hook scripts key on the 1.x name `bash`.
function toolName(tool: string): string {
  return tool === "shell" ? "bash" : tool;
}

async function runHook(
  hook: Hook,
  payload: string,
  directory: string
): Promise<void> {
  const timeout = hook.timeout ?? DEFAULT_TIMEOUT_MS;
  const child = Bun.spawn(["sh", "-c", hook.command!], {
    cwd: directory,
    env: {
      ...process.env,
      CLAUDE_PROJECT_DIR: directory,
      OPENCODE_COMPAT: "true",
    },
    stdin: new TextEncoder().encode(payload),
    stdout: "ignore",
    stderr: "pipe",
  });
  let timedOut = false;
  const timer = setTimeout(() => {
    timedOut = true;
    child.kill();
  }, timeout);
  const [code, stderr] = await Promise.all([
    child.exited,
    new Response(child.stderr).text(),
  ]);
  clearTimeout(timer);
  if (timedOut) {
    throw new Error(
      `BLOCKED: hook timed out after ${timeout}ms: ${hook.command}`
    );
  }
  if (code === 2) {
    throw new Error(stderr.trim() || `BLOCKED by hook: ${hook.command}`);
  }
}

async function gate(
  tool: string,
  input: unknown,
  sessionID: string | undefined,
  directory: string
): Promise<void> {
  const name = toolName(tool);
  for (const entry of preToolUse()) {
    if (!new RegExp(`^(${entry.matcher ?? ".*"})$`).test(name)) continue;
    for (const hook of entry.hooks ?? []) {
      if (hook.type !== "command" || !hook.command) continue;
      const payload = JSON.stringify({
        hook_event_name: "PreToolUse",
        session_id: sessionID ?? "",
        cwd: directory,
        tool_name: name,
        tool_input: input ?? {},
      });
      await runHook(hook, payload, directory);
    }
  }
}

export default {
  id: "claude-hooks",
  server: async ({ directory }: { directory: string }) => ({
    "tool.execute.before": async (
      input: { tool: string; sessionID?: string },
      output: { args: unknown }
    ) => {
      await gate(input.tool, output.args, input.sessionID, directory);
    },
  }),
  setup: async (ctx: {
    location: { directory: string };
    tool: {
      hook: (
        name: "execute.before",
        callback: (event: {
          tool: string;
          sessionID: string;
          input: unknown;
        }) => Promise<void>
      ) => Promise<unknown>;
    };
  }) => {
    await ctx.tool.hook("execute.before", async (event) => {
      await gate(
        event.tool,
        event.input,
        event.sessionID,
        ctx.location.directory
      );
    });
  },
};
