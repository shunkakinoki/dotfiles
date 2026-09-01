---
name: traces
description: "Publish OpenClaw sessions to Traces on session, message, and command lifecycle events"
metadata:
  {
    "openclaw":
      {
        "emoji": "📡",
        "events":
          [
            "agent:bootstrap",
            "message:received",
            "message:sent",
            "command:new",
            "command:stop",
          ],
      },
  }
---

# Traces Hook

Forwards OpenClaw lifecycle events to `traces hook agent <event> --agent openclaw`.

## Event Mapping

| OpenClaw event     | Traces event       |
| ------------------ | ------------------ |
| `agent:bootstrap`  | `session-start`    |
| `message:received` | `prompt-submitted` |
| `message:sent`     | `agent-done`       |
| `command:new`      | `session-end`      |
| `command:stop`     | `session-end`      |

## Requirements

- The `traces` CLI on `PATH`, or installed under `~/.bun/install/global/node_modules/.bin`.
- A logged-in Traces account (`traces whoami`).
- A folder share rule covering the workspace directory. `traces` resolves the
  destination namespace from the working directory, refuses to run outside a git
  repository, and drops uploads without an error when the nearest matching
  folder rule is `"off"`.

## Disabling

```json
{
  "hooks": {
    "internal": {
      "entries": {
        "traces": { "enabled": false }
      }
    }
  }
}
```
