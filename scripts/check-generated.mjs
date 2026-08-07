import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { readdir, readFile, stat } from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("..", import.meta.url));
const generatedPaths = ["frontend/src/client", "frontend/src/routeTree.gen.ts"];
const before = await fingerprint(generatedPaths);
const npm = process.platform === "win32" ? "npm.cmd" : "npm";
const result = spawnSync(npm, ["run", "generate-client"], { cwd: root, stdio: "inherit" });

if (result.error) throw result.error;
if (result.status !== 0) process.exit(result.status ?? 1);

const after = await fingerprint(generatedPaths);
if (before !== after) {
  console.error(
    "\nGenerated client or route tree was stale and has been refreshed. " +
      "Review and commit the generated changes, then run `npm run check` again.",
  );
  process.exit(1);
}

async function fingerprint(entries) {
  const hash = createHash("sha256");
  for (const entry of entries) await add(entry, hash);
  return hash.digest("hex");
}

async function add(relativePath, hash) {
  const absolutePath = path.join(root, relativePath);
  const metadata = await stat(absolutePath).catch(() => undefined);
  hash.update(relativePath);
  hash.update("\0");
  if (!metadata) return hash.update("missing\0");
  if (metadata.isFile()) {
    hash.update(await readFile(absolutePath));
    return;
  }
  for (const name of (await readdir(absolutePath)).sort()) {
    await add(path.join(relativePath, name), hash);
  }
}
