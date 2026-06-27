import socket

from flask import Flask, jsonify

# Flask framework (Python). API variant — returns JSON.
app = Flask(__name__)


@app.get("/health")
def health():
    return "ok"


@app.get("/")
def root():
    # Backing services on lds-network: mysql:3306 postgres:5432 redis:6379 ...
    return jsonify(
        service="svc-template-flask",
        message="Hello from Flask",
        hostname=socket.gethostname(),
    )
