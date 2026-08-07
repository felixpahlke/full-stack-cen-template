import path from "node:path";
import process from "node:process";
import { defineConfig, devices } from "@playwright/test";

try {
  process.loadEnvFile(path.resolve(import.meta.dirname, "../.env"));
} catch {
  // `npm run dev` prints the actionable missing-env message.
}

const webPort = process.env.WEB_PORT || "5173";
const webUrl = process.env.PLAYWRIGHT_BASE_URL || `http://localhost:${webPort}`;
const apiPort = process.env.API_PORT || "8000";
const externalServer = process.env.PLAYWRIGHT_EXTERNAL_SERVER === "true";
const containerized = process.env.PLAYWRIGHT_CONTAINER === "true";

export default defineConfig({
  testDir: "./tests",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: "list",
  use: {
    baseURL: webUrl,
    trace: "on-first-retry",
    launchOptions: containerized
      ? { args: ["--host-resolver-rules=MAP localhost host.docker.internal"] }
      : undefined,
  },
  projects: [
    { name: "setup", testMatch: /.*\.setup\.ts/ },
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"], storageState: "playwright/.auth/user.json" },
      dependencies: ["setup"],
    },
  ],
  webServer: externalServer
    ? undefined
    : {
        command: "npm --prefix .. run dev",
        url: `http://localhost:${apiPort}/api/v1/utils/health-check/`,
        timeout: 180_000,
        reuseExistingServer: !process.env.CI,
        gracefulShutdown: { signal: "SIGTERM", timeout: 10_000 },
      },
});
