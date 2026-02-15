# Plan: Add WhatsApp broadcast groups with multi-model agents

## Context

Add broadcast groups so three models (Opus, Sonnet, GLM) respond in parallel to every WhatsApp message.

## Changes to `config/openclaw/openclaw.tpl.json`

### 1. Add sonnet + glm agents to `agents.list`

```json
{
  "id": "sonnet",
  "model": {
    "primary": "cliproxy/__CLAUDE_SONNET__"
  }
},
{
  "id": "glm",
  "model": {
    "primary": "cliproxy/__GLM__"
  }
}
```

### 2. Add top-level `broadcast` section

```json
"broadcast": {
  "strategy": "parallel",
  "*": ["main", "sonnet", "glm"]
}
```

### 3. Run `llm-update.sh`, `make format`, commit and push PR

## Files

- `config/openclaw/openclaw.tpl.json`
