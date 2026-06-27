// Your scheduled task. Output goes to stdout (lds app logs). Keep it idempotent.
const os = require("os");
console.log(`[${new Date().toISOString()}] cron-template-node: ran on ${os.hostname()}`);

// Backing services are reachable by name on lds-network, e.g.:
//   await fetch("http://my-svc:8080/health")
//   const mysql = require("mysql2/promise"); // add to package.json
//   await mysql.createConnection({ host: "mysql", user: "root", password: "root" })
