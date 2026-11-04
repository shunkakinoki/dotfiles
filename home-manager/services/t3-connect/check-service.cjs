// A launcher can stay active after its child loses the ownership lock. Check
// the serving process, not the launcher's MainPID, before reporting readiness.
const fs = require("node:fs/promises");
const path = require("node:path");

async function main() {
  const base = process.env.T3CODE_HOME || path.join(process.env.HOME, ".t3");
  const proc = process.env.T3_PROC_ROOT || "/proc";
  const deadline =
    Date.now() + Number(process.env.T3_SERVICE_READY_TIMEOUT_MS || 30000);
  for (;;) {
    try {
      const state = JSON.parse(
        await fs.readFile(
          path.join(base, "userdata/server-runtime.json"),
          "utf8"
        )
      );
      if (!Number.isSafeInteger(state.pid) || state.pid <= 0)
        throw new Error("Invalid server PID");
      process.kill(state.pid, 0);
      const [cgroup, environ] = await Promise.all([
        fs.readFile(path.join(proc, String(state.pid), "cgroup"), "utf8"),
        fs.readFile(path.join(proc, String(state.pid), "environ"), "utf8"),
      ]);
      if (
        !/\/t3code\.service(?:\/|\n|$)/m.test(cgroup) ||
        !environ
          .split("\0")
          .some(
            (entry) =>
              entry.startsWith("T3_SERVICE_LAUNCHER_CONTEXT=") &&
              entry.length > "T3_SERVICE_LAUNCHER_CONTEXT=".length
          )
      ) {
        throw new Error(
          "A server outside the managed launcher owns this T3 home; automatic updates are unavailable. Preserve its work and hand it over to t3code.service. No process was stopped."
        );
      }
      console.log("T3 serving process belongs to the managed launcher.");
      return;
    } catch (error) {
      // Missing/stale runtime records are expected while the service starts.
      if (!["ENOENT", "ESRCH"].includes(error.code) || Date.now() >= deadline)
        throw error;
      await new Promise((resolve) => setTimeout(resolve, 200));
    }
  }
}

main().catch((error) => {
  console.error(`T3 service readiness failed: ${error.message}`);
  process.exitCode = 1;
});
