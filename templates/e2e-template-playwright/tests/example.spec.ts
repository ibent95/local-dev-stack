import { test, expect } from '@playwright/test';

// Smoke tests against the target app (baseURL from playwright.config.ts).
// The runner container resolves *.test through the stack's in-network DNS, so
// http://<name>.test-style URLs reach apps on lds-network just like a browser
// on the host would.

test('app is reachable and renders content', async ({ page }) => {
  const response = await page.goto('/');
  expect(response?.status()).toBeLessThan(500);
  await expect(page.locator('body')).not.toBeEmpty();
});

test('page sets a title', async ({ page }) => {
  await page.goto('/');
  const title = await page.title();
  expect(title.trim().length).toBeGreaterThan(0);
});
