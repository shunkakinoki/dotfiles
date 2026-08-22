// Runtime model fallback for Pi.
//
// Pi's built-in `retry` setting only retries the same model, so this walks an
// ordered chain from ~/.pi/agent/fallback.json when a provider keeps failing.
//
// Pi is the only host that needs this. OMP implements fallback chains natively
// (`retry.fallbackChains`, configured in config/omp/config.yml) and OpenCode
// uses opencode-runtime-fallback, which switches models by aborting the
// in-flight session request and replaying message parts through the OpenCode
// server API. The config schema here mirrors config/opencode/opencode-fallback.jsonc
// minus `timeout_seconds`, which an extension cannot honor on Pi.
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export interface FallbackConfig {
  enabled: boolean;
  retry_on_errors: number[];
  retryable_error_patterns: string[];
  max_fallback_attempts: number;
  cooldown_seconds: number;
  notify_on_fallback: boolean;
  fallback_models: string[];
}

export const DEFAULT_CONFIG: FallbackConfig = {
  enabled: false,
  retry_on_errors: [401, 404, 429, 500, 502, 503, 504],
  retryable_error_patterns: [],
  max_fallback_attempts: 5,
  cooldown_seconds: 60,
  notify_on_fallback: true,
  fallback_models: [],
};

function arrayOf<T>(
  value: unknown,
  guard: (item: unknown) => item is T
): T[] | undefined {
  return Array.isArray(value) && value.every(guard)
    ? (value as T[])
    : undefined;
}

const isString = (value: unknown): value is string => typeof value === "string";
const isNumber = (value: unknown): value is number =>
  typeof value === "number" && Number.isFinite(value);
const isBoolean = (value: unknown): value is boolean =>
  typeof value === "boolean";

/**
 * Reads the policy document, keeping the default for any field whose type is
 * wrong. A malformed config must degrade to DEFAULT_CONFIG (fallback disabled)
 * rather than throw later from inside a host event handler.
 */
export function parseFallbackConfig(raw: unknown): FallbackConfig {
  if (!raw || typeof raw !== "object" || Array.isArray(raw))
    return DEFAULT_CONFIG;
  const input = raw as Record<string, unknown>;
  const pick = <T>(key: keyof FallbackConfig, value: T | undefined): T =>
    value === undefined ? (DEFAULT_CONFIG[key] as unknown as T) : value;

  return {
    enabled: pick(
      "enabled",
      isBoolean(input.enabled) ? input.enabled : undefined
    ),
    retry_on_errors: pick(
      "retry_on_errors",
      arrayOf(input.retry_on_errors, isNumber)
    ),
    retryable_error_patterns: pick(
      "retryable_error_patterns",
      arrayOf(input.retryable_error_patterns, isString)
    ),
    max_fallback_attempts: pick(
      "max_fallback_attempts",
      isNumber(input.max_fallback_attempts)
        ? input.max_fallback_attempts
        : undefined
    ),
    cooldown_seconds: pick(
      "cooldown_seconds",
      isNumber(input.cooldown_seconds) ? input.cooldown_seconds : undefined
    ),
    notify_on_fallback: pick(
      "notify_on_fallback",
      isBoolean(input.notify_on_fallback) ? input.notify_on_fallback : undefined
    ),
    fallback_models: pick(
      "fallback_models",
      arrayOf(input.fallback_models, isString)
    ),
  };
}

export function loadFallbackConfig(path: string): FallbackConfig {
  try {
    return parseFallbackConfig(JSON.parse(readFileSync(path, "utf8")));
  } catch {
    return DEFAULT_CONFIG;
  }
}

/** Model ids may contain slashes (openrouter-preset/@preset/glm-4-7), so split once. */
export function splitModelRef(ref: string): { provider: string; id: string } {
  const index = ref.indexOf("/");
  return index === -1
    ? { provider: "", id: ref }
    : { provider: ref.slice(0, index), id: ref.slice(index + 1) };
}

export function modelRef(
  model: { provider?: string; id?: string } | undefined
): string {
  return model ? `${model.provider ?? ""}/${model.id ?? ""}` : "";
}

export type FallbackDecision =
  | { action: "ignore" }
  | { action: "exhausted"; reason: string }
  | { action: "switch"; from: string; to: string; status?: number };

export interface FallbackPolicy {
  /** Latest provider HTTP status, used to classify the next error. */
  recordStatus(status: number | undefined): void;
  /** A user-driven model switch restarts the chain from the newly chosen model. */
  noteManualSelection(): void;
  /** The model to restore after a clean turn, once its cooldown expired. Does not consume it. */
  pendingRestore(now?: number): string | undefined;
  /** Drop the remembered primary, once the host confirmed the restore. */
  confirmRestore(): void;
  /** Reset the attempt counter after a clean turn. */
  noteSuccess(): void;
  /** Called after a failed turn. Decides whether and where to fall back. */
  onError(
    currentRef: string,
    errorMessage: string,
    now?: number
  ): FallbackDecision;
  /** Cool a model down after the host failed to select it. */
  markUnavailable(ref: string, now?: number): void;
  /** Confirm a switch the host actually applied. */
  commit(): void;
}

export function createFallbackPolicy(config: FallbackConfig): FallbackPolicy {
  const cooldownUntil = new Map<string, number>();
  let lastStatus: number | undefined;
  let attempts = 0;
  let primaryRef: string | undefined;

  const isRetryable = (errorMessage: string): boolean => {
    if (lastStatus !== undefined && config.retry_on_errors.includes(lastStatus))
      return true;
    const haystack = errorMessage.toLowerCase();
    return config.retryable_error_patterns.some((pattern) =>
      haystack.includes(pattern.toLowerCase())
    );
  };

  const coolDown = (ref: string, now: number) => {
    cooldownUntil.set(ref, now + config.cooldown_seconds * 1000);
  };

  return {
    recordStatus(status) {
      lastStatus = status;
    },

    noteManualSelection() {
      attempts = 0;
      primaryRef = undefined;
    },

    noteSuccess() {
      attempts = 0;
    },

    pendingRestore(now = Date.now()) {
      if (!primaryRef || (cooldownUntil.get(primaryRef) ?? 0) > now)
        return undefined;
      return primaryRef;
    },

    confirmRestore() {
      primaryRef = undefined;
    },

    onError(currentRef, errorMessage, now = Date.now()) {
      if (!isRetryable(errorMessage)) return { action: "ignore" };
      if (attempts >= config.max_fallback_attempts) {
        return {
          action: "exhausted",
          reason: `gave up after ${attempts} attempts`,
        };
      }

      coolDown(currentRef, now);
      if (!primaryRef) primaryRef = currentRef;

      const next = config.fallback_models.find(
        (ref) => ref !== currentRef && (cooldownUntil.get(ref) ?? 0) <= now
      );
      if (!next)
        return { action: "exhausted", reason: "no fallback model available" };

      return {
        action: "switch",
        from: currentRef,
        to: next,
        status: lastStatus,
      };
    },

    markUnavailable(ref, now = Date.now()) {
      coolDown(ref, now);
    },

    commit() {
      attempts += 1;
      lastStatus = undefined;
    },
  };
}

/** The slice of Pi's ExtensionAPI this needs. */
interface FallbackHost {
  on(event: string, handler: (event: unknown, ctx: unknown) => unknown): void;
  ui: { notify(message: string, type?: "info" | "warning" | "error"): void };
  modelRegistry: { find(provider: string, modelId: string): unknown };
  setModel(model: unknown): Promise<boolean>;
  sendMessage(
    message: { customType: string; content: string; display: boolean },
    options?: { triggerTurn?: boolean }
  ): void;
}

function attachFallback(host: FallbackHost, configPath: string): void {
  const config = loadFallbackConfig(configPath);
  if (!config.enabled || config.fallback_models.length === 0) return;

  const policy = createFallbackPolicy(config);
  // Ref of the model this extension last selected, so a model that is active
  // without us having chosen it can only have come from the user. Pi emits
  // model_select and OMP does not, so both hosts are covered by comparing
  // ctx.model instead of subscribing to an event only one of them has.
  let appliedRef: string | undefined;

  const notify = (message: string, level: "info" | "warning" = "info") => {
    if (config.notify_on_fallback)
      host.ui.notify(`[fallback] ${message}`, level);
  };

  const selectRef = async (ref: string): Promise<boolean> => {
    const { provider, id } = splitModelRef(ref);
    const model = host.modelRegistry.find(provider, id);
    if (!model) return false;
    if (!(await host.setModel(model))) return false;
    appliedRef = ref;
    return true;
  };

  host.on("after_provider_response", (event) => {
    policy.recordStatus((event as { status?: number }).status);
  });

  host.on("agent_end", async (event, ctx) => {
    const messages = (event as { messages?: unknown[] }).messages ?? [];
    const last = messages[messages.length - 1] as
      | { role?: string; stopReason?: string; errorMessage?: string }
      | undefined;
    const currentRef = modelRef(
      (ctx as { model?: { provider?: string; id?: string } }).model
    );

    // The user switched models behind our back: their choice wins outright.
    if (appliedRef !== undefined && currentRef !== appliedRef) {
      appliedRef = undefined;
      policy.noteManualSelection();
    }

    if (last?.role !== "assistant" || last.stopReason !== "error") {
      policy.noteSuccess();
      const restore = policy.pendingRestore();
      if (restore && (await selectRef(restore))) {
        policy.confirmRestore();
        notify(`restored ${restore}`);
      }
      return;
    }

    const errorMessage = last.errorMessage ?? "";
    let decision = policy.onError(currentRef, errorMessage);
    if (decision.action === "ignore") return;

    // A candidate the host cannot select is cooled down and skipped, so an
    // unregistered or unauthenticated model does not strand the whole chain.
    while (decision.action === "switch") {
      if (await selectRef(decision.to)) {
        policy.commit();
        notify(
          `${decision.from} failed (${decision.status ?? "error"}) -> ${decision.to}`,
          "warning"
        );
        host.sendMessage(
          {
            customType: "runtime-fallback",
            content: "Continue.",
            display: false,
          },
          { triggerTurn: true }
        );
        return;
      }
      policy.markUnavailable(decision.to);
      notify(`${decision.to} unavailable`, "warning");
      decision = policy.onError(currentRef, errorMessage);
    }

    if (decision.action === "exhausted") notify(decision.reason, "warning");
  });
}

export default function piRuntimeFallback(pi: ExtensionAPI): void {
  attachFallback(
    pi as unknown as FallbackHost,
    join(homedir(), ".pi", "agent", "fallback.json")
  );
}
