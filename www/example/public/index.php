<?php
// Sample project — proves auto-vhosting + extensions + service reachability.
// Visit:  http://example.test
header('Content-Type: text/plain; charset=utf-8');

$want = ['rdkafka', 'redis', 'memcached', 'pdo_mysql', 'pdo_pgsql', 'opcache', 'intl', 'bcmath', 'gd', 'zip', 'sockets'];

echo "example.test — PHP " . PHP_VERSION . "\n";
echo "served from: " . __DIR__ . "\n";
echo str_repeat('=', 40) . "\n\n";

echo "Extensions:\n";
foreach ($want as $ext) {
    printf("  [%s] %s\n", extension_loaded($ext) ? 'x' : ' ', $ext);
}

echo "\nServices reachable on lds-network:\n";
$targets = [
    'mysql'     => ['mysql', 3306],
    'postgres'  => ['postgres', 5432],
    'redis'     => ['redis', 6379],
    'memcached' => ['memcached', 11211],
    'kafka'     => ['kafka-broker', 9092],
];
foreach ($targets as $label => [$host, $port]) {
    $c = @fsockopen($host, $port, $e, $s, 1.0);
    printf("  [%s] %s (%s:%d)\n", $c ? 'x' : ' ', $label, $host, $port);
    if ($c) { fclose($c); }
}
