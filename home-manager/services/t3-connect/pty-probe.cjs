const pty = require(process.argv[2]);
const marker = "t3-native-terminal-ready";
const terminal = pty.spawn(process.execPath, ["-e", `process.stdout.write(${JSON.stringify(marker)})`], {
  cwd: process.cwd(),
  env: process.env,
});
let output = "";
const timeout = setTimeout(() => {
  console.error("T3 native terminal probe timed out");
  terminal.kill();
  process.exit(1);
}, 5000);
terminal.onData((data) => { output += data; });
terminal.onExit(({ exitCode }) => {
  clearTimeout(timeout);
  if (exitCode !== 0 || !output.includes(marker)) {
    console.error("T3 native terminal probe failed");
    process.exitCode = 1;
  }
});
