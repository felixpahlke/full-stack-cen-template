import path from "node:path";
import process from "node:process";
import { defineConfig, devices } from "@playwright/test";

try {
  process.loadEnvFile(path.resolve(import.meta.dirname, "../.env"));
} catch {
  // `pnpm run dev` provides the actionable missing-environment message.
}

const proxyPort = process.env.OAUTH2_PROXY_PORT || "4180";
const proxyUrl = process.env.PLAYWRIGHT_BASE_URL || `http://localhost:${proxyPort}`;
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
    baseURL: proxyUrl,
    trace: "on-first-retry",
    launchOptions: containerized
      ? { args: ["--host-resolver-rules=MAP localhost host.docker.internal"] }
      : undefined,
  },
  projects: [
    { name: "setup", testMatch: /.*\.setup\.ts/ },
    {
      name: "chromium",
      use: {
        ...devices["Desktop Chrome"],
        storageState: "playwright/.auth/user.json",
      },
      dependencies: ["setup"],
    },
  ],
  webServer: externalServer
    ? undefined
    : {
        command: "pnpm --dir .. run dev",
        url: `${proxyUrl}/ping`,
        timeout: 180_000,
        reuseExistingServer: !process.env.CI,
        gracefulShutdown: { signal: "SIGTERM", timeout: 10_000 },
      },
});
