<?php
require __DIR__ . '/../vendor/autoload.php';

use Slim\Factory\AppFactory;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

// Slim micro-framework (PHP). Web variant — server-rendered HTML.
$app = AppFactory::create();

$app->get('/health', function (Request $req, Response $res) {
    $res->getBody()->write('ok');
    return $res;
});

$app->get('/', function (Request $req, Response $res) {
    $host = gethostname();
    $res->getBody()->write(
        "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">"
        . "<title>web-template-slim</title>"
        . "<style>body{font:16px/1.6 system-ui,sans-serif;max-width:40rem;margin:4rem auto;padding:0 1rem}</style>"
        . "</head><body><h1>web-template-slim</h1>"
        . "<p>Hello from a Slim server-rendered page.</p>"
        . "<p>Host: <code>{$host}</code></p></body></html>"
    );
    return $res->withHeader('Content-Type', 'text/html');
});

$app->run();
