#!/usr/bin/env bash
# Register OpenFactor's host-scoped orchestration hooks when the OpenFactor CLI
# is installed. The CLI owns harness adapters and receipts; this wrapper only
# provides the durable Home Manager activation boundary.
# Hook registration is optional, so a missing, outdated, or failing CLI warns
# instead of aborting the rest of Home Manager activation.
set -euo pipefail

OPENFACTOR_BIN="${OPENFACTOR_BIN:-}"
if [[ -z $OPENFACTOR_BIN ]]; then
  OPENFACTOR_BIN="$(PATH="$HOME/.local/bin:${PATH:-}" command -v openfactor 2>/dev/null || true)"
fi

if [[ -z $OPENFACTOR_BIN ]]; then
  echo "OpenFactor CLI not found; skipping orchestration hook registration" >&2
  exit 0
fi

if [[ ! -x $OPENFACTOR_BIN ]]; then
  echo "warning: OpenFactor CLI is not executable: $OPENFACTOR_BIN; skipping orchestration hook registration" >&2
  exit 0
fi

if ! "$OPENFACTOR_BIN" hooks install --scope host --json; then
  echo "warning: OpenFactor hook registration failed; continuing activation" >&2
fi

# The generated OpenCode plugin spawns one CLI process per event, and the
# message part events fire on every streamed token. Under a busy T3 server that
# forks hundreds of hooks per second and drives the host load into the
# hundreds, so keep only the coarse-grained session and tool events.
opencode_plugin="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/plugins/openfactor-hooks.ts"
if [[ -f $opencode_plugin && ! -L $opencode_plugin ]]; then
  sed -i.bak -E 's/"message\.part\.(delta|updated)",?//g; s/,\]/]/' "$opencode_plugin"
  rm -f "$opencode_plugin.bak"
fi

# The generated pi extension writes each payload to the hook over a socketpair.
# pi exits right after session_shutdown, and the Bun-built CLI then blocks on
# that stdin forever, so every pi run strands a few hooks. Hand the payload
# over as an unlinked regular file instead, which always reads to EOF.
pi_extension="$HOME/.pi/agent/extensions/openfactor-hooks.ts"
if [[ -f $pi_extension && ! -L $pi_extension ]] && grep -q 'stdio: \["pipe"' "$pi_extension"; then
  # shellcheck disable=SC2016
  "${OPENFACTOR_PERL:-perl}" -0pi -e '
    s{(import \{ spawn \} from "node:child_process";\n)}{$1import { closeSync, openSync, unlinkSync, writeFileSync } from "node:fs";\nimport { tmpdir } from "node:os";\nimport { join } from "node:path";\n};
    s{function send\(.*?\n\}\n}{function send(event: string, payload: unknown): void {
  try {
    const file = join(tmpdir(), `openfactor-pi-\${process.pid}-\${Date.now()}-\${Math.random().toString(36).slice(2)}.json`);
    writeFileSync(file, JSON.stringify(payload ?? {}), { flag: "wx", mode: 0o600 });
    const fd = openSync(file, "r");
    unlinkSync(file);
    const child = spawn(client, ["pi-hook", event], { stdio: [fd, "ignore", "ignore"], detached: true });
    closeSync(fd);
    child.on("error", () => {});
    child.unref();
  } catch {}
}
}s;
  ' "$pi_extension"
fi
