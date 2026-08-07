import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("..", import.meta.url));
const routeTree = readFileSync(path.join(root, "frontend/src/routeTree.gen.ts"), "utf8");

test("generated OAuth Carbon route surface stays limited to home and items", () => {
  const fullPathInterface = routeTree.match(
    /export interface FileRoutesByFullPath \{(?<routes>[\s\S]*?)\n\}/,
  );
  assert.ok(fullPathInterface?.groups?.routes, "FileRoutesByFullPath is missing");

  const routes = [...fullPathInterface.groups.routes.matchAll(/^\s+'([^']+)':/gm)].map(
    ([, route]) => route,
  );

  assert.deepEqual(routes, ["/", "/items"]);
});
