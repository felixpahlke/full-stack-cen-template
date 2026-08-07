import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("..", import.meta.url));
const ignored = new Set(["client", "dist", "node_modules"]);
const violations = [];

for (const filename of sourceFiles(path.join(root, "frontend"))) {
  const relative = path.relative(root, filename);
  if (relative === "frontend/src/routeTree.gen.ts") continue;
  for (const [index, line] of readFileSync(filename, "utf8").split("\n").entries()) {
    if (/@ts-(?:ignore|nocheck)\b/.test(line)) {
      violations.push(`${relative}:${index + 1}: @ts-ignore and @ts-nocheck are forbidden`);
    }
    if (/@ts-expect-error\b/.test(line) && !/@ts-expect-error:\s+.{3,}/.test(line)) {
      violations.push(`${relative}:${index + 1}: @ts-expect-error needs a description`);
    }
  }
}

if (violations.length) {
  console.error(violations.join("\n"));
  process.exitCode = 1;
}

function* sourceFiles(directory) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    if (ignored.has(entry.name)) continue;
    const filename = path.join(directory, entry.name);
    if (entry.isDirectory()) yield* sourceFiles(filename);
    else if (entry.isFile() && /\.[cm]?[jt]sx?$/.test(entry.name)) yield filename;
  }
}
