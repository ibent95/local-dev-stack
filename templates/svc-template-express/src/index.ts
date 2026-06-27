import express from "express";
import os from "node:os";

const app = express();
const port = 3000;

app.get("/health", (_req, res) => {
  res.send("ok");
});

app.get("/", (_req, res) => {
  // Backing services on lds-network: mysql:3306, postgres:5432, redis:6379,
  // kafka-broker:9092 ...
  res.json({
    service: "node",
    message: "Hello from Node + Express + TypeScript",
    hostname: os.hostname(),
  });
});

app.listen(port, () => {
  console.log(`node listening on :${port}`);
});
