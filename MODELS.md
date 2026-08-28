# Models

Default and fallback model assignments for every harness in this repo.

## Source of truth

[models.json](models.json) maps a stable alias to a concrete model ID. Templates
(`*.tpl.*`) reference the alias as an `__UPPER_SNAKE__` placeholder;
[scripts/llm-update.sh](scripts/llm-update.sh) sed-substitutes them into the
generated configs.

```bash
make llm-update
```

Never hand-edit a generated config. Edit the `.tpl.*` file, regenerate, and commit both.

### Aliases

| Placeholder | Model ID |
| --- | --- |
| `__CLAUDE_OPUS__` | `claude-opus-5` |
| `__CLAUDE_SONNET__` | `claude-sonnet-5` |
| `__CLAUDE_HAIKU__` | `claude-haiku-4-5-20251001` |
| `__GPT__` | `gpt-5.6-sol` |
| `__GPT_LUNA__` | `gpt-5.6-luna` |
| `__GPT_IMAGE__` | `gpt-image-2` |
| `__GEMINI_PRO__` | `gemini-3.1-pro-low` |
| `__GEMINI_FLASH__` | `gemini-3.7-flash-high` |
| `__DEEPSEEK_FLASH__` | `deepseek-v4-flash` |
| `__DEEPSEEK_PRO__` | `deepseek-v4-pro` |
| `__GEMMA_LOCAL__` | `gemma3:4b` |
| `__MINIMAX__` | `minimax-m3` |
| `__KIMI__` | `kimi-k3` |
| `__GROK__` | `grok-4.5` |
| `__QWEN__` | `qwen3.6-plus` |
| `__QWEN_LOCAL__` | `qwen3.5-0.8b-optiq` |

This table is the complete set of keys in [models.json](models.json). Every key
also gets two derived forms: `__<KEY>_PRETTY__` for the display name
("Deepseek V4 Flash") and `__<KEY>_NONDOT__` for the dot-stripped ID, used in
OpenRouter `@preset/` names.

Provider-specific slugs remain separate even when they represent the same model
family. `__GEMINI_PRO__` and `__GEMINI_FLASH__` are IDs verified through
CLIProxy, while Antigravity's native model ID stays directly in its
provider-owned template.

Two provider-specific overrides are declared in
[scripts/llm-update.sh](scripts/llm-update.sh) rather than in `models.json`,
because the upstream ID differs from the canonical one:

| Placeholder | Value | Used by |
| --- | --- | --- |
| `__GPT_IMAGE_OPENROUTER__` | `openai/gpt-5.4-image-2` | OpenRouter, aliased back to `gpt-image-2` |
| `__DEEPSEEK_FLASH_0731__` | `deepseek-v4-flash-0731` | Aliyun, aliased back to `deepseek-v4-flash` |

## The shared fallback chain

Harnesses that support runtime fallback use one chain, in this order:

```
deepseek-v4-flash  (primary)
  -> free           (OpenRouter free router, last resort)
```

Rules:

- `deepseek-v4-flash` is the only DeepSeek model on any automatic path.
  `deepseek-v4-pro` stays in the CLIProxy catalog and is addressable by explicit
  request, but it is never a fallback hop and never a default.
- Every hop resolves through CLIProxy, so provider-level rotation (OpenCode ->
  Aliyun -> OpenRouter) already happens inside a single hop. Do not add a hop
  that repeats the primary model.
- Keep the chain model-diverse. Each hop should be a different vendor family so
  a vendor-wide outage cannot exhaust the chain.

## Per-harness assignments

### Fallback-capable

| Harness | Default | Fallback chain | Config |
| --- | --- | --- | --- |
| OpenCode | `shunkakinoki/deepseek-v4-flash` | shared chain, `shunkakinoki/` prefix | [opencode-fallback.tpl.jsonc](config/opencode/opencode-fallback.tpl.jsonc) |
| OpenClaw | `cliproxy/deepseek-v4-flash` | shared chain, `cliproxy/` prefix | [openclaw.tpl.json](config/openclaw/openclaw.tpl.json) |
| Hermes | `cliproxy/deepseek-v4-flash` | shared chain via `fallback_providers` | [config.tpl.yaml](config/hermes/config.tpl.yaml) |
| OMP | `cliproxyapi/deepseek-v4-flash` | shared chain, `cliproxyapi/` prefix | [config.tpl.yml](config/omp/config.tpl.yml) |

OpenCode fallback is driven by the `opencode-runtime-fallback@0.2.3` plugin:

| Setting | Value |
| --- | --- |
| `retry_on_errors` | `401, 404, 429, 500, 502, 503, 504` |
| `retryable_error_patterns` | `unknown provider for model` |
| `max_fallback_attempts` | `5` |
| `cooldown_seconds` | `60` |
| `timeout_seconds` | `30` |

OpenClaw and Hermes have no equivalent error-pattern matcher, so they hard-fail
on the `unknown provider for model <prefixed-name>` 400 that OpenCode absorbs.
OMP uses native `retry.fallbackChains` instead of a plugin.

Hermes also runs a Mixture-of-Agents preset: reference models
`deepseek-v4-flash` + `minimax-m3`, aggregator `deepseek-v4-flash`.

### No fallback chain

| Harness | Role | Model | Config |
| --- | --- | --- | --- |
| OpenCode | `small_model` | `shunkakinoki/deepseek-v4-flash` | [opencode.tpl.jsonc](config/opencode/opencode.tpl.jsonc) |
| OpenCode | `code-reviewer` agent | `shunkakinoki/deepseek-v4-flash` | [opencode.tpl.jsonc](config/opencode/opencode.tpl.jsonc) |
| OMP | `smol`, `commit`, `task` | `cliproxyapi/free` | [config.tpl.yml](config/omp/config.tpl.yml) |
| OMP | `slow`, `vision`, `plan` | `cliproxyapi/deepseek-v4-flash` | |
| Codex | default | `gpt-5.6-sol` | [config.tpl.toml](config/codex/config.tpl.toml) |
| Codex | subagents | `gpt-5.6-luna` | |
| Codex | `qwen-local` profile | `qwen3.5-0.8b-optiq` (LM Studio) | |
| Antigravity | default | `gemini-3.7-flash-high` (native Antigravity provider) | [settings.tpl.json](config/antigravity/settings.tpl.json) |
| Pi | `defaultModel` | `free` (provider `cliproxyapi`) | [settings.tpl.json](config/pi/settings.tpl.json) |
| Factory (droid) | session default | `deepseek-v4-flash-0731` (Droid Core) | [settings.tpl.json](config/factory/settings.tpl.json) |
| Factory (droid) | custom models | `custom:deepseek-v4-flash-0`, `custom:free-1` via `https://cliproxy.shunkakinoki.com/v1` | [settings.tpl.json](config/factory/settings.tpl.json) |
| aichat | default | `cliproxy:deepseek-v4-flash` | [config.tpl.yaml](config/aichat/config.tpl.yaml) |
| DSH web | default | `deepseek-v4-flash` via `https://cliproxy.shunkakinoki.com/v1` (native DeepSeek adapter) | [settings.tpl.yaml](config/dsh/settings.tpl.yaml) |
| llm | default | `deepseek-v4-flash` | [default_model.tpl.txt](config/llm/default_model.tpl.txt) |
| Handy | transcript post-process | `@preset/deepseek-v4-flash` (OpenRouter) | [settings_store.tpl.json](config/handy/settings_store.tpl.json) |

OMP selects only `cliproxyapi/*`. Subagent overrides use
`deepseek-v4-flash` for the hard-task roles and `free` for the lightweight
roles.
The registry in [models.tpl.yml](config/omp/models.tpl.yml) lists the
CLIProxy aliases and discovers the rest from remote `/v1/models`.
OMP fallback uses the shared chain (`deepseek-v4-flash` -> `free`).

### Fish shortcuts

The `l` suffix means local (LM Studio), `h` means headless.

| Function | Model |
| --- | --- |
| `ocxe`, `ocxeh` | `cliproxyapi/deepseek-v4-flash` |
| `ocxel`, `ocxelh` | `lmstudio/qwen3.5-0.8b-optiq` |
| `coxe`, `coxeh` | `gpt-5.6-sol` |
| `coxel`, `coxelh` | `qwen3.5-0.8b-optiq` (`--oss --local-provider lmstudio`) |
| `pixe`, `pixeh` | `cliproxyapi/deepseek-v4-flash` |
| `pixel`, `pixelh` | `lmstudio/qwen3.5-0.8b-optiq` |

## CLIProxy routing

Three provider prefixes appear above. All three are CLIProxy. Each harness names
its own, so the prefix alone does not tell you remote vs local. `cliproxyapi/`
in particular means different endpoints in different harnesses.

| Prefix | Harness | Endpoint |
| --- | --- | --- |
| `shunkakinoki/` | OpenCode | `https://cliproxy.shunkakinoki.com/v1` (remote) |
| `cliproxy/` | OpenClaw, Hermes | `https://cliproxy.shunkakinoki.com/v1` (remote) |
| `cliproxyapi/` | OpenCode | `http://localhost:8317/v1` (local) |
| `cliproxyapi/` | OMP | `https://cliproxy.shunkakinoki.com/v1` (remote) |
| `cliproxyapi/` | Pi | `https://cliproxy.shunkakinoki.com/v1` (remote) |

Every one of them resolves through
[config.tpl.yaml](config/cliproxyapi/config.tpl.yaml). Higher `priority` wins.

| Provider | Priority | DeepSeek models served |
| --- | --- | --- |
| `opencode` | 300 | `deepseek-v4-pro`, `deepseek-v4-flash` |
| `aliyun` | 200 | `deepseek-v4-pro`, `deepseek-v4-flash-0731` aliased to `deepseek-v4-flash` |
| `openrouter` | 100 | `@preset/deepseek-v4-pro`, `@preset/deepseek-v4-flash` |

So a single `deepseek-v4-flash` request tries OpenCode Zen, then Aliyun, then
OpenRouter before the harness-level fallback chain sees a failure.

## Changing a model

1. To swap a model version everywhere: edit [models.json](models.json), run
   `make llm-update`, commit the template and generated files together.
2. To change a default or a fallback hop for one harness: edit that harness's
   `.tpl.*` file, run `make llm-update`.
3. Update the matching assertions in `spec/llm_update_spec.sh`,
   `spec/openclaw_hydrate_spec.sh`, `spec/hermes_hydrate_spec.sh`, and
   `spec/cliproxyapi_spec.sh`, then run `shellspec`.
