import socket

from fastapi import FastAPI

# FastAPI framework (Python). API variant — returns JSON.
app = FastAPI()


@app.get("/health")
def health():
    return "ok"


@app.get("/")
def root():
    # Backing services on lds-network: mysql:3306 postgres:5432 redis:6379 ...
    return {
        "service": "svc-template-fastapi",
        "message": "Hello from FastAPI",
        "hostname": socket.gethostname(),
    }
