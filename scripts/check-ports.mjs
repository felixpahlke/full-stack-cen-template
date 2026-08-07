import { connect } from "node:net";
import process from "node:process";
import { fileURLToPath } from "node:url";

import { buildEffectiveEnvironment } from "./dev-environment.mjs";

const root = fileURLToPath(new URL("..", import.meta.url));
let environment;

try {
  environment = buildEffectiveEnvironment(root);
} catch (error) {
  fail(error.message);
}

const rawPort = environment.API_PORT;
const apiPort = Number(rawPort);
if (!Number.isInteger(apiPort) || apiPort < 1 || apiPort > 65535) {
  fail(`API_PORT must be an integer between 1 and 65535 (received ${JSON.stringify(rawPort)}).`);
}

if (!(await isFree(apiPort))) {
  fail(`API_PORT=${apiPort} is occupied. Update API_PORT in .env, then run npm run dev again.`);
}

console.log(`local port ready: API ${apiPort}`);

function isFree(port) {
  return new Promise((resolve) => {
    const socket = connect({ host: "127.0.0.1", port });
    socket.unref();
    socket.once("connect", () => {
      socket.destroy();
      resolve(false);
    });
    socket.once("error", (error) => resolve(error.code === "ECONNREFUSED"));
  });
}

function fail(message) {
  console.error(`\n✗ ${message}`);
  process.exit(1);
}
