import express from "express";
import os from "node:os";

// Server-rendered web counterpart of svc-template-node (which returns JSON).
const app = express();
const port = 3000;

app.get("/health", (_req, res) => {
  res.send("ok");
});

app.get("/", (_req, res) => {
  // Backing services on lds-network: mysql:3306 postgres:5432 redis:6379 ...
  res.type("html").send(`<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>web-template-express</title>
<style>body{font:16px/1.6 system-ui,sans-serif;max-width:40rem;margin:4rem auto;padding:0 1rem}</style>
</head><body>
  <h1>web-template-express</h1>
  <p>Hello from a Node + Express server-rendered page.</p>
  <p>Host: <code>${os.hostname()}</code></p>
</body></html>`);
});

app.listen(port, () => {
  console.log(`web-template-express listening on :${port}`);
});
