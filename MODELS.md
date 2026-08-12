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
| `__GPT_CODEX__` | `gpt-5.3-codex` |
| `__GPT_CODEX_SPARK__` | `gpt-5.3-codex-spark` |
| `__GEMINI_PRO__` | `gemini-3.1-pro-preview` |
| `__GEMINI_FLASH__` | `gemini-3.6-flash` |
| `__DEEPSEEK_FLASH__` | `deepseek-v4-flash` |
| `__DEEPSEEK_PRO__` | `deepseek-v4-pro` |
| `__GLM__` | `glm-4.7` |
| `__GEMMA__` | `gemma-4-31b-it` |
| `__GEMMA_LOCAL__` | `gemma3:4b` |
| `__MINIMAX__` | `minimax-m3` |
| `__KIMI__` | `kimi-k3` |
| `__GROK__` | `grok-4.5` |
| `__QWEN__` | `qwen3.6-plus` |
| `__QWEN_LOCAL__` | `qwen3.5-0.8b-optiq` |

## The shared fallback chain

Harnesses that support runtime fallback use one chain, in this order:

```
deepseek-v4-flash  (primary)
  -> gemma-4-31b-it
  -> glm-4.7
  -> minimax-m3
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

Hermes also runs a Mixture-of-Agents preset: reference models
`deepseek-v4-flash` + `minimax-m3`, aggregator `deepseek-v4-flash`.

### No fallback chain

| Harness | Role | Model | Config |
| --- | --- | --- | --- |
| OpenCode | `small_model` | `glm-4.7` | [opencode.tpl.jsonc](config/opencode/opencode.tpl.jsonc) |
| OpenCode | `code-reviewer` agent | `deepseek-v4-flash` | [opencode.tpl.jsonc](config/opencode/opencode.tpl.jsonc) |
| OMP | `default` | `cliproxyapi/deepseek-v4-flash` | [config.tpl.yml](config/omp/config.tpl.yml) |
| OMP | `smol` | `openai-codex/gpt-5.6-luna` | |
| OMP | `slow`, `vision`, `plan` | `openai-codex/gpt-5.6-sol` | |
| OMP | `commit` | `openai/gpt-5.6-luna` | |
| OMP | `task` | `openai-codex/gpt-5.3-codex-spark` | |
| Codex | default | `gpt-5.6-sol` | [config.tpl.toml](config/codex/config.tpl.toml) |
| Codex | subagents | `gpt-5.6-luna` | |
| Codex | `qwen-local` profile | `qwen3.5-0.8b-optiq` (LM Studio) | |
| Pi | `defaultModel` | `glm-4.7` (provider `cliproxyapi`) | [settings.tpl.json](config/pi/settings.tpl.json) |
| Factory (droid) | session default | `deepseek-v4-flash` | [settings.tpl.json](config/factory/settings.tpl.json) |
| Factory (droid) | custom local | `gemma3:4b` (Ollama) | |
| aichat | default | `cliproxy:glm-4.7` | [config.tpl.yaml](config/aichat/config.tpl.yaml) |
| llm | default | `glm-4.7` | [default_model.tpl.txt](config/llm/default_model.tpl.txt) |
| Handy | transcript post-process | `@preset/glm-4.7` (OpenRouter) | [settings_store.tpl.json](config/handy/settings_store.tpl.json) |

OMP subagent overrides: `code-explorer` uses `gpt-5.3-codex-spark`;
`comment-analyzer` and `pr-test-analyzer` use `gpt-5.6-luna`; the rest
(`code-architect`, `code-reviewer`, `code-simplifier`, `silent-failure-hunter`,
`type-design-analyzer`) use `gpt-5.6-sol`.

### CCS profiles

Claude Code Switch swaps the whole Anthropic model triple per profile.

| Profile | Opus + Sonnet slot | Haiku slot |
| --- | --- | --- |
| `agy` | `claude-opus-5` | `claude-sonnet-5` |
| `codex` | `gpt-5.3-codex` | `gpt-5.3-codex` |
| `gemini` | `gemini-3.1-pro-preview` | `gemini-3.6-flash` |
| `glm` | `glm-4.7` | `glm-4.7` |

### Fish shortcuts

The `l` suffix means local (LM Studio), `h` means headless.

| Function | Model |
| --- | --- |
| `ocxe`, `ocxeh` | `cliproxyapi/deepseek-v4-flash` |
| `ocxel`, `ocxelh` | `lmstudio/qwen3.5-0.8b-optiq` |
| `coxe`, `coxeh` | `gpt-5.6-sol` |
| `coxel`, `coxelh` | `qwen3.5-0.8b-optiq` (`--oss --local-provider lmstudio`) |
| `pixe`, `pixeh` | `cliproxyapi/glm-4.7` |
| `pixel`, `pixelh` | `lmstudio/qwen3.5-0.8b-optiq` |

## CLIProxy routing

Every `cliproxy/` and `cliproxyapi/` model resolves through
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
