import http from "node:http";
import os from "node:os";

// Native Node web tech: the built-in `http` module (no framework).
const port = 3000;

const page = (host: string) => `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>web-template-node</title>
<style>body{font:16px/1.6 system-ui,sans-serif;max-width:40rem;margin:4rem auto;padding:0 1rem}</style>
</head><body>
  <h1>web-template-node</h1>
  <p>Hello from a Node server-rendered page (http module).</p>
  <p>Host: <code>${host}</code></p>
</body></html>`;

const server = http.createServer((req, res) => {
  if (req.url === "/health") {
    res.writeHead(200, { "Content-Type": "text/plain" });
    res.end("ok");
    return;
  }
  res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
  res.end(page(os.hostname()));
});

server.listen(port, () => {
  console.log(`web-template-node listening on :${port}`);
});
