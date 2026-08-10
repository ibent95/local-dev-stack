# <NAME> — Playwright E2E tests

End-to-end tests for **<NAME>** (target: `<URL>`), run inside the
local-dev-stack Playwright runner.

## Run

```bash
lds playwright run <name>
```

Pass extra Playwright CLI args after the project name:

```bash
lds playwright run <name> -- --project=chromium --grep "smoke"
```

## Record a test

```bash
lds playwright codegen <URL>
```

## Watch it live

`lds playwright run` writes an HTML report to the shared report folder, served
at `http://playwright.test/<name>` (start the viewer with `lds up playwright`).

## Notes

- The runner container (`lds-playwright`) is pre-warmed by `lds up playwright`;
  browsers are already installed in the image — no `npx playwright install`.
- First run in a fresh project runs `npm install` inside the container.
- Change the target app by editing `baseURL` in `playwright.config.ts` or by
  passing `E2E_BASE_URL` when running.
