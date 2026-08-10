import { defineConfig, devices } from '@playwright/test';
import path from 'node:path';

// HTML report lands in the shared /e2e/reports/<project> folder, which the
// local-dev-stack viewer serves at http://playwright.test/<project>.
const reportDir = path.join('/e2e/reports', path.basename(__dirname));

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  timeout: 60_000,
  retries: 0,
  reporter: [
    ['html', { outputFolder: reportDir, open: 'never' }],
    ['line'],
  ],
  use: {
    // Target of the E2E tests — set at scaffold time (`lds playwright init
    // <name> <url>`) or override with E2E_BASE_URL when running.
    baseURL: process.env.E2E_BASE_URL || '<URL>',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
    { name: 'webkit', use: { ...devices['Desktop Safari'] } },
  ],
});
