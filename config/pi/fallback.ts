// Runtime model fallback for Pi. Pi's built-in `retry` setting only retries the
// same model; this walks the chain in ~/.pi/agent/fallback.json instead.
// Logic lives in ../fallback-policy.ts (config/shared/fallback/runtime-fallback.ts).
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { attachFallback, type FallbackHost } from "../fallback-policy.ts";

export default function piRuntimeFallback(pi: ExtensionAPI): void {
  attachFallback(
    pi as unknown as FallbackHost,
    join(homedir(), ".pi", "agent", "fallback.json")
  );
}
