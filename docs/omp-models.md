# OMP Model Resolution

How Oh My Pi resolves model strings from agent frontmatter into concrete API calls.

---

## The `pi/` Role Prefix

Agents reference models using the `pi/` prefix in frontmatter:

```yaml
# Agent frontmatter
---
name: explore
model: pi/smol         # resolved via config.yml modelRoles
thinking-level: off
---

# Subagent (inline in agents.ts)
{ frontmatter: { name: "task", model: "pi/task", thinkingLevel: Effort.Medium } }
```

**Supported roles** (`MODEL_ROLE_IDS`):

| Role     | Purpose                          |
|----------|----------------------------------|
| `default`| Fallback model                   |
| `smol`   | Small / fast model               |
| `slow`   | Large / capable model            |
| `vision` | Vision-capable model             |
| `plan`   | Planning / architecture model    |
| `commit` | Commit message model             |
| `task`   | Subagent model                  |

> Note: If a role is not defined in `config.yml`'s `modelRoles`, it passes through unchanged and will fail to resolve at runtime.

---

## Layer 1 — Provider Definitions (`models.yml` / `models.json`)

Custom providers and models are defined in:

- **Primary**: `~/.omp/agent/models.yml`
- **Legacy fallback**: `~/.omp/agent/models.json` (auto-migrated to YAML on first load)
- **Dotfiles**: `config/pi/models.json` → symlinked via Nix to `~/.omp/agent/models.json`

### `models.yml` Shape

```yaml
providers:
  <provider-id>:
    baseUrl: https://api.example.com/v1
    apiKey: MY_PROVIDER_API_KEY        # env var name or literal token
    api: openai-responses             # see below
    auth: apiKey                      # or: none
    authHeader: true                  # injects Authorization: Bearer header
    headers:
      X-Team: platform
    discovery:
      type: ollama                     # or: llama.cpp
    modelOverrides:
      some-model-id:
        name: Renamed model
    models:
      - id: some-model-id
        name: Some Model
        api: openai-completions       # override at model level
        reasoning: false
        input: [text]                 # or: [text, image]
        cost:
          input: 0
          output: 0
          cacheRead: 0
          cacheWrite: 0
        contextWindow: 128000
        maxTokens: 16384
        headers:
          X-Model: value
        compat:
          supportsStore: true
          supportsDeveloperRole: true
          supportsReasoningEffort: true
          maxTokensField: max_completion_tokens
          openRouterRouting:
            only: [anthropic]
          vercelGatewayRouting:
            order: [anthropic, openai]
          extraBody:
            gateway: m1-01
```

### Allowed `api` Values

| API                          | Transport              |
|------------------------------|------------------------|
| `openai-completions`         | OpenAI Completions API |
| `openai-responses`           | OpenAI Responses API   |
| `openai-codex-responses`     | OpenAI Codex (WebSocket) |
| `azure-openai-responses`     | Azure OpenAI           |
| `anthropic-messages`         | Anthropic Messages API |
| `google-generative-ai`       | Google AI (Gemini)     |
| `google-vertex`              | Google Vertex AI       |

### Implicit Local Discovery

If not explicitly configured, OMP auto-adds discovery providers:

| Provider   | Default URL                  | Auth |
|------------|------------------------------|------|
| `ollama`   | `http://127.0.0.1:11434`   | none |
| `llama.cpp`| `http://127.0.0.1:8080`     | none |
| `lm-studio`| `http://127.0.0.1:1234/v1` | none |

Runtime discovery calls the provider's `/api/tags`, `/models`, or equivalent endpoint and synthesizes model entries.

### Dotfiles Providers

The dotfiles `config/pi/models.json` defines two providers:

**`cliproxyapi`** — proxies GPT-5, Claude, Gemini, and others:

- `gpt-5.3-codex` / `gpt-5.4` — OpenAI Codex responses, reasoning, vision
- `gemini-3.1-pro-preview` / `gemini-3.1-flash-preview` — Google Gemini
- `claude-opus-4-6` — Anthropic Opus, reasoning, vision
- `claude-sonnet-4-6` — Anthropic Sonnet, vision
- `claude-haiku-4-5-20251001` — Anthropic Haiku
- `minimax-m2.5` — reasoning, free
- `glm-4.7` — Z-AI, free

**`lmstudio`** — local LLM via LM Studio:

- `qwen/qwen3.5-9b` — Qwen 3.5 9B, reasoning, free

---

## Layer 2 — Role Aliases (`config.yml` `modelRoles`)

The `config/omp/config.yml` `modelRoles` block maps role names to concrete model strings. These are resolved via `Settings.load()` from `~/.omp/agent/config.yml` (symlinked via `default.nix`).

```yaml
modelRoles:
  default: codex/gpt-5.4       # only role currently configured
```

> The dotfiles currently only defines `default`. All other roles (`smol`, `slow`, `vision`, `plan`, `commit`, `task`) are not mapped — agents referencing them will fall through to the passthrough and fail at resolution time unless `models.yml` happens to contain a matching entry.

---

## Resolution Pipeline

**Entry point**: `expandRoleAlias(value: string, settings?: Settings)` (`model-resolver.ts`)

```typescript
const PREFIX_MODEL_ROLE = "pi/";

export function expandRoleAlias(value: string, settings?: Settings): string {
  const normalized = value.trim();
  if (normalized === DEFAULT_MODEL_ROLE) {
    return settings?.getModelRole("default") ?? value;
  }
  const resolved = resolveConfiguredRolePattern(value, settings);
  return resolved ?? value;
}

function resolveConfiguredRolePattern(value: string, settings?: Settings): string | undefined {
  // 1. Parse optional :thinkingLevel suffix
  const lastColonIndex = normalized.lastIndexOf(":");
  const thinkingLevel =
    lastColonIndex > PREFIX_MODEL_ROLE.length
      ? parseThinkingLevel(normalized.slice(lastColonIndex + 1))
      : undefined;
  // 2. Strip pi/ prefix and validate against MODEL_ROLE_IDS
  const aliasCandidate = thinkingLevel ? normalized.slice(0, lastColonIndex) : normalized;
  const role = getModelRoleAlias(aliasCandidate);
  if (!role) return normalized;  // not a role alias, passthrough
  // 3. Look up in modelRoles
  const configured = settings?.getModelRole(role)?.trim();
  if (!configured) return undefined;
  // 4. Append thinking suffix if specified
  return thinkingLevel ? `${configured}:${thinkingLevel}` : configured;
}

function getModelRoleAlias(value: string): ModelRole | undefined {
  const normalized = value.trim();
  if (!normalized.startsWith(PREFIX_MODEL_ROLE)) return undefined;
  const candidate = normalized.slice(PREFIX_MODEL_ROLE.length);
  for (const role of MODEL_ROLE_IDS) {
    if (candidate === role) return role;
  }
  return undefined;
}
```

**Step-by-step for `"pi/smol:high"`**:

1. `"pi/smol:high"` → strip suffix `":high"` → thinkingLevel = `"high"`
2. `"pi/smol"` → strip `"pi/"` prefix → `"smol"` → matches `MODEL_ROLE_IDS`
3. `settings.getModelRole("smol")` → `undefined` (not configured in dotfiles)
4. Returns `undefined` → `expandRoleAlias` returns input unchanged: `"pi/smol:high"`
5. `"pi/smol:high"` falls through to model matching in `parseModelPattern` where it is split again on `:` → `"pi/smol"` is tried, fails, then `"pi/smol"` → `undefined`, warning emitted

**Step-by-step for `"pi/default"`**:

1. `"pi/default"` equals `DEFAULT_MODEL_ROLE` → direct lookup: `settings.getModelRole("default")` → `"codex/gpt-5.4"`
2. Result: `"codex/gpt-5.4"`

---

## Thinking Level Suffix Syntax

After a role resolves, an optional `:thinkingLevel` suffix controls reasoning effort. Valid labels from `ThinkingLevel`:

| Label     | Thinking Level                      |
|-----------|-------------------------------------|
| `:off`    | No reasoning (thinking disabled)     |
| `:minimal`| Minimal reasoning effort            |
| `:low`    | Light reasoning (~2k tokens)        |
| `:medium` | Medium reasoning                    |
| `:high`   | Deep reasoning (~16k tokens)         |
| `:xhigh`  | Extra high reasoning                |

> The `ThinkingLevel.Inherit` value (`"inherit"`) is internal and not exposed as a suffix label.

**Examples**:

- `pi/default` → `codex/gpt-5.4` (configured default)
- `pi/smol:high` → fails to resolve (smol role undefined in dotfiles config)
- `anthropic/claude-sonnet-4-6:high` → Sonnet with deep reasoning enabled

---

## Model Matching Modes

After `expandRoleAlias` produces a concrete string, `parseModelPattern(...)` matches it against available models using this priority:

### `tryMatchModel` algorithm

1. **Exact `provider/modelId`** (case-insensitive):
   ```typescript
   const providerMatch = availableModels.find(
     m => m.provider.toLowerCase() === provider.toLowerCase()
       && m.id.toLowerCase() === modelId.toLowerCase()
   );
   ```
   If found, return immediately.

2. **Provider-scoped fuzzy** (if `provider/` prefix present but no exact model match):
   Filter models by provider, then `fuzzyMatch(modelId, model.id)`.

3. **Exact model ID** (case-insensitive, across all providers):
   ```typescript
   const exactMatches = availableModels.filter(
     m => m.id.toLowerCase() === modelPattern.toLowerCase()
   );
   ```

4. **Partial/substring match** (ID or `name`):
   ```typescript
   const matches = availableModels.filter(
     m => m.id.toLowerCase().includes(modelPattern.toLowerCase())
       || m.name?.toLowerCase().includes(modelPattern.toLowerCase())
   );
   ```

5. **Alias vs dated version resolution**:
   - Aliases (IDs ending in `-latest` or no date suffix) preferred over dated versions (`-YYYYMMDD`)
   - For multiple dated versions, picks the lexicographically newest ID

6. **Preference tiebreaking**: Recent usage order → provider usage → declaration order → deprioritized providers (`openrouter` last)

### Glob scope patterns

When a pattern contains `*`, `?`, or `[`, `resolveModelScope` uses `Bun.Glob` matching:

```typescript
const glob = new Bun.Glob(globPattern.toLowerCase());
return glob.match(fullId.toLowerCase()) || glob.match(m.id.toLowerCase());
```

Example: `"openai/*:medium"` → all OpenAI models with medium thinking.

### `findInitialModel` priority

When selecting the initial model without an explicit pattern:

1. Explicit CLI `--model` argument
2. First scoped model (if not resuming session)
3. Saved default provider/model
4. Known provider defaults (OpenAI / Anthropic / Google / etc.) among available models
5. First available model

---

## Context Promotion (Overflow Recovery)

When a request fails with a context length error (`context_length_exceeded`), `AgentSession` attempts promotion **before** compaction:

1. If `contextPromotion.enabled` is true, resolve promotion target
2. If a target is found, switch to it and retry — no compaction needed
3. If no target, fall through to auto-compaction

### Target selection (model-driven, not role-driven)

1. `currentModel.contextPromotionTarget` (explicit, configured in `models.yml`)
2. Smallest larger-context model on the same provider + API

### Explicit fallback chain

Configure in `models.yml`:

```yaml
providers:
  openai-codex:
    modelOverrides:
      gpt-5.3-codex-spark:
        contextPromotionTarget: openai-codex/gpt-5.3-codex
```

The built-in model generator also assigns this automatically for `*-spark` models when a same-provider base model exists.

---

## Auth and API Key Resolution

When resolving a key for a provider, effective order is:

1. CLI runtime override (`--api-key`)
2. Stored API key in `agent.db`
3. Stored OAuth credential in `agent.db` (with refresh)
4. Environment variable (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, etc.)
5. `models.yml` `apiKey` field (treated as env var name first, then literal)

Keyless providers (`auth: none`) are always available without credentials.

---

## Common Patterns

### Local OpenAI-compatible endpoint

```yaml
providers:
  local:
    baseUrl: http://127.0.0.1:8000/v1
    auth: none
    api: openai-completions
    models:
      - id: Qwen/Qwen2.5-Coder-32B-Instruct
        name: Qwen 2.5 Coder 32B (local)
```

### Override built-in provider route

```yaml
providers:
  openrouter:
    baseUrl: https://my-proxy.example.com/v1
    headers:
      X-Team: platform
    modelOverrides:
      anthropic/claude-sonnet-4:
        name: Sonnet 4 (Corp)
        compat:
          openRouterRouting:
            only: [anthropic]
```

### Proxy with env-based key

```yaml
providers:
  anthropic-proxy:
    baseUrl: https://proxy.example.com/anthropic
    apiKey: ANTHROPIC_PROXY_API_KEY
    api: anthropic-messages
    authHeader: true
    models:
      - id: claude-sonnet-4-20250514
        name: Claude Sonnet 4 (Proxy)
        reasoning: true
        input: [text, image]
```

---

## Reference

- Resolution logic: `packages/coding-agent/src/config/model-resolver.ts`
- Model registry + `MODEL_ROLE_IDS`: `packages/coding-agent/src/config/model-registry.ts`
- Thinking levels: `packages/agent/src/thinking.ts`, `packages/ai/src/model-thinking.ts`
- Config schema: `docs/models.md` (OMP source)
- Local config: `config/omp/config.yml`, `config/pi/models.json`
