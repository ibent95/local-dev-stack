<?php
require __DIR__ . '/../vendor/autoload.php';

use Slim\Factory\AppFactory;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

// Slim micro-framework (PHP). API variant — returns JSON.
$app = AppFactory::create();

$app->get('/health', function (Request $req, Response $res) {
    $res->getBody()->write('ok');
    return $res;
});

$app->get('/', function (Request $req, Response $res) {
    // Backing services on lds-network: mysql:3306 postgres:5432 redis:6379 ...
    $res->getBody()->write(json_encode([
        'service' => 'svc-template-slim',
        'message' => 'Hello from Slim',
        'hostname' => gethostname(),
    ]));
    return $res->withHeader('Content-Type', 'application/json');
});

$app->run();
