import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./tests/e2e",
  timeout: 90_000,
  expect: {
    timeout: 10_000
  },
  fullyParallel: false,
  retries: 0,
  use: {
    baseURL: "http://127.0.0.1:4173",
    trace: "on-first-retry"
  },
  webServer: {
    command: "AUTH_REQUIRED=0 PORT=4173 node server.mjs",
    url: "http://127.0.0.1:4173/health",
    reuseExistingServer: true,
    timeout: 120_000
  }
});

