// Loads a page in headless Chromium, runs probe.js, saves a 2x capture with
// the guides drawn and the measurements as JSON, and prints a summary.
//
//   PW_DIR=<dir with playwright> node audit.mjs <url> <outDir> [width=1440] [prep.mjs]
//
// prep.mjs (optional) default-exports async (page) => {} to open a menu,
// switch a tab or sign in before measuring.
//
// Optional environment:
//   CHROMIUM_PATH  use an existing Chromium build instead of Playwright's
//   SCHEME         light | dark (default: no preference)
//   SETTLE_MS      wait after load before measuring (default 3000)
//   CONTAINERS     CSS selectors to measure instead of the defaults
//   TAG            suffix for the output file names
import { createRequire } from "node:module";
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const [, , url, outDir, width = "1440", prepPath] = process.argv;
if (!url || !outDir) {
  console.error("usage: node audit.mjs <url> <outDir> [width] [prep.mjs]");
  process.exit(1);
}

const require = createRequire(join(resolve(process.env.PW_DIR || process.cwd()), "noop.js"));
const { chromium } = require("playwright");
const here = dirname(fileURLToPath(import.meta.url));

const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined });
const page = await browser.newPage({
  viewport: { width: +width, height: 900 },
  deviceScaleFactor: 2,
  colorScheme: process.env.SCHEME || "no-preference",
});
await page.goto(url, { waitUntil: "domcontentloaded", timeout: 240_000 });
await page.waitForTimeout(+(process.env.SETTLE_MS || 3000));
if (prepPath) {
  const prep = (await import(pathToFileURL(resolve(prepPath)).href)).default;
  await prep(page);
}
await page.addScriptTag({ content: readFileSync(join(here, "probe.js"), "utf8") });
const result = await page.evaluate(
  (containers) => window.__gridlines({ containers: containers || undefined }),
  process.env.CONTAINERS || "",
);

mkdirSync(outDir, { recursive: true });
const { protocol, pathname } = new URL(url);
const target = protocol === "file:" ? pathname.split("/").pop() : pathname;
const slug = `${target.replace(/\W+/g, "-").replace(/^-|-$/g, "") || "root"}-${width}${process.env.TAG ? `-${process.env.TAG}` : ""}`;
writeFileSync(join(outDir, `${slug}.json`), JSON.stringify(result, null, 1));
await page.screenshot({ path: join(outDir, `${slug}.png`) });
await browser.close();

for (const c of result) {
  const fmt = (v) => (v === undefined ? "-" : `${v}px`);
  const { lead, box, iconCentre, label, trailing, trailCentre } = c.lines;
  console.log(`\n## ${c.container}  x${c.x} w${c.w}`);
  console.log(`   lead ${fmt(lead)}  box ${fmt(box)}  icon centre ${fmt(iconCentre)}  label ${fmt(label)}  trailing ${fmt(trailing)}  trailing centre ${fmt(trailCentre)}`);
  for (const o of c.outliers)
    console.log(`   MISS y${o.y} ${o.edge}: ${o.px}px vs ${o.line}px  ${o.item}`);
}
console.log(`\ncapture: ${join(outDir, `${slug}.png`)}`);
