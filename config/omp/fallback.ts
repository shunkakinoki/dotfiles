// Runtime model fallback for OMP. OMP's built-in `retry` setting only retries
// the same model; this walks the chain in ~/.omp/agent/fallback.json instead.
// Logic lives in ../fallback-policy.ts (config/shared/fallback/runtime-fallback.ts).
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent/extensibility/extensions";
import { attachFallback, type FallbackHost } from "../fallback-policy.ts";

export default function ompRuntimeFallback(pi: ExtensionAPI): void {
  attachFallback(
    pi as unknown as FallbackHost,
    join(homedir(), ".omp", "agent", "fallback.json")
  );
}
