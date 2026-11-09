// Validates demo-data-manager.html before it ships:
//   1. the <script type="text/babel"> block parses as JSX (catches the errors Babel
//      Standalone would otherwise only report in the browser at load time);
//   2. APP_VERSION matches the newest "## vX.Y.Z" heading in docs/CHANGELOG.md.
// Usage: node check-jsx.mjs <path/to/demo-data-manager.html> [path/to/CHANGELOG.md]
import { readFileSync } from "node:fs";
import { parse } from "@babel/parser";

const [htmlPath, changelogPath] = process.argv.slice(2);
if (!htmlPath) {
  console.error("usage: node check-jsx.mjs <html> [changelog]");
  process.exit(2);
}

const fail = (msg) => {
  console.error(`✗ ${msg}`);
  process.exit(1);
};

const html = readFileSync(htmlPath, "utf8");
const blocks = [...html.matchAll(/<script type="text\/babel">([\s\S]*?)<\/script>/g)];
if (blocks.length !== 1) fail(`expected exactly 1 text/babel script block, found ${blocks.length}`);

try {
  parse(blocks[0][1], { sourceType: "script", plugins: ["jsx"] });
} catch (e) {
  // Babel's line numbers are relative to the script block; translate to file lines.
  const offset = html.slice(0, blocks[0].index).split("\n").length - 1;
  const line = e.loc ? e.loc.line + offset : "?";
  fail(`JSX parse error at ${htmlPath}:${line} — ${e.message}`);
}
console.log("✓ JSX parses");

const version = html.match(/const APP_VERSION = "([^"]+)";/)?.[1];
if (!version) fail("APP_VERSION not found");
console.log(`✓ APP_VERSION ${version}`);

if (changelogPath) {
  const top = readFileSync(changelogPath, "utf8").match(/^## v(\d+\.\d+\.\d+)/m)?.[1];
  if (!top) fail(`no "## vX.Y.Z" heading found in ${changelogPath}`);
  if (top !== version) fail(`APP_VERSION ${version} does not match newest CHANGELOG entry v${top}`);
  console.log("✓ CHANGELOG is up to date");
}
