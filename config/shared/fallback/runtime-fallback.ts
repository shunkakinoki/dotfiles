// Host-agnostic runtime model fallback.
//
// Shared by the Pi and OMP extensions (config/pi/fallback.ts,
// config/omp/fallback.ts), which are thin wrappers around `attachFallback`.
// Both hosts expose the same extension surface: `after_provider_response` for
// the HTTP status, `agent_end` for the outcome of a turn, and `setModel` to
// switch in place.
//
// OpenCode is deliberately NOT a consumer. opencode-runtime-fallback switches
// models by aborting the in-flight session request and replaying message parts
// through the OpenCode server API; none of that machinery is portable here.
// It shares the config schema below, not this code.
import { readFileSync } from "node:fs";

export interface FallbackConfig {
  enabled: boolean;
  retry_on_errors: number[];
  retryable_error_patterns: string[];
  max_fallback_attempts: number;
  cooldown_seconds: number;
  timeout_seconds: number;
  notify_on_fallback: boolean;
  fallback_models: string[];
}

export const DEFAULT_CONFIG: FallbackConfig = {
  enabled: false,
  retry_on_errors: [401, 404, 429, 500, 502, 503, 504],
  retryable_error_patterns: [],
  max_fallback_attempts: 5,
  cooldown_seconds: 60,
  timeout_seconds: 30,
  notify_on_fallback: true,
  fallback_models: [],
};

export function loadFallbackConfig(path: string): FallbackConfig {
  try {
    const raw = JSON.parse(
      readFileSync(path, "utf8")
    ) as Partial<FallbackConfig>;
    return { ...DEFAULT_CONFIG, ...raw };
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
  /** Called after a clean turn. Returns the model to restore, if its cooldown expired. */
  onSuccess(now?: number): string | undefined;
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

    onSuccess(now = Date.now()) {
      attempts = 0;
      if (!primaryRef || (cooldownUntil.get(primaryRef) ?? 0) > now)
        return undefined;
      const restored = primaryRef;
      primaryRef = undefined;
      return restored;
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

/** The slice of the Pi/OMP ExtensionAPI this needs. Hosts pass their `pi` object. */
export interface FallbackHost {
  on(event: string, handler: (event: unknown, ctx: unknown) => unknown): void;
  ui: { notify(message: string, type?: "info" | "warning" | "error"): void };
  modelRegistry: { find(provider: string, modelId: string): unknown };
  setModel(model: unknown): Promise<boolean>;
  sendMessage(
    message: { customType: string; content: string; display: boolean },
    options?: { triggerTurn?: boolean }
  ): void;
}

export function attachFallback(host: FallbackHost, configPath: string): void {
  const config = loadFallbackConfig(configPath);
  if (!config.enabled || config.fallback_models.length === 0) return;

  const policy = createFallbackPolicy(config);
  let switching = false;

  const notify = (message: string, level: "info" | "warning" = "info") => {
    if (config.notify_on_fallback)
      host.ui.notify(`[fallback] ${message}`, level);
  };

  const selectRef = async (ref: string): Promise<boolean> => {
    const { provider, id } = splitModelRef(ref);
    const model = host.modelRegistry.find(provider, id);
    if (!model) return false;
    switching = true;
    try {
      return await host.setModel(model);
    } finally {
      switching = false;
    }
  };

  host.on("after_provider_response", (event) => {
    policy.recordStatus((event as { status?: number }).status);
  });

  // OMP has no model_select event; there the chain just never resets early.
  try {
    host.on("model_select", () => {
      if (!switching) policy.noteManualSelection();
    });
  } catch {
    // host does not support the event
  }

  host.on("agent_end", async (event, ctx) => {
    const messages = (event as { messages?: unknown[] }).messages ?? [];
    const last = messages[messages.length - 1] as
      | { role?: string; stopReason?: string; errorMessage?: string }
      | undefined;

    if (last?.role !== "assistant" || last.stopReason !== "error") {
      const restore = policy.onSuccess();
      if (restore && (await selectRef(restore))) notify(`restored ${restore}`);
      return;
    }

    const currentRef = modelRef(
      (ctx as { model?: { provider?: string; id?: string } }).model
    );
    const decision = policy.onError(currentRef, last.errorMessage ?? "");
    if (decision.action === "ignore") return;
    if (decision.action === "exhausted") {
      notify(decision.reason, "warning");
      return;
    }

    if (!(await selectRef(decision.to))) {
      policy.markUnavailable(decision.to);
      notify(`${decision.to} unavailable`, "warning");
      return;
    }

    policy.commit();
    notify(
      `${decision.from} failed (${decision.status ?? "error"}) -> ${decision.to}`,
      "warning"
    );
    host.sendMessage(
      { customType: "runtime-fallback", content: "Continue.", display: false },
      { triggerTurn: true }
    );
  });
}
