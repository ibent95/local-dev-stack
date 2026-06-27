import socket

from fastapi import FastAPI
from fastapi.responses import HTMLResponse

# FastAPI framework (Python). Web variant — server-rendered HTML.
app = FastAPI()


@app.get("/health")
def health():
    return "ok"


@app.get("/", response_class=HTMLResponse)
def root():
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>web-template-fastapi</title>
<style>body{{font:16px/1.6 system-ui,sans-serif;max-width:40rem;margin:4rem auto;padding:0 1rem}}</style>
</head><body>
  <h1>web-template-fastapi</h1>
  <p>Hello from a FastAPI server-rendered page.</p>
  <p>Host: <code>{socket.gethostname()}</code></p>
</body></html>"""
