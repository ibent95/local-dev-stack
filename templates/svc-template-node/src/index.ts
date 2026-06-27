import http from "node:http";
import os from "node:os";

// Native Node web tech: the built-in `http` module (no framework).
const port = 3000;

const server = http.createServer((req, res) => {
  if (req.url === "/health") {
    res.writeHead(200, { "Content-Type": "text/plain" });
    res.end("ok");
    return;
  }
  // Backing services on lds-network: mysql:3306 postgres:5432 redis:6379 ...
  res.writeHead(200, { "Content-Type": "application/json" });
  res.end(JSON.stringify({
    service: "svc-template-node",
    message: "Hello from Node (http module)",
    hostname: os.hostname(),
  }));
});

server.listen(port, () => {
  console.log(`svc-template-node listening on :${port}`);
});
