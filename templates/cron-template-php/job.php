<?php
// Your scheduled task. Output goes to stdout (lds app logs). Keep it idempotent.
echo sprintf("[%s] cron-template-php: ran on %s\n", date('c'), gethostname());

// Backing services are reachable by name on lds-network, e.g.:
//   $pdo = new PDO('mysql:host=mysql;dbname=app', 'root', 'root');
//   file_get_contents('http://my-svc:8080/health');
