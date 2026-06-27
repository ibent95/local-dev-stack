import socket

from flask import Flask

# Flask framework (Python). Web variant — server-rendered HTML.
app = Flask(__name__)


@app.get("/health")
def health():
    return "ok"


@app.get("/")
def root():
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>web-template-flask</title>
<style>body{{font:16px/1.6 system-ui,sans-serif;max-width:40rem;margin:4rem auto;padding:0 1rem}}</style>
</head><body>
  <h1>web-template-flask</h1>
  <p>Hello from a Flask server-rendered page.</p>
  <p>Host: <code>{socket.gethostname()}</code></p>
</body></html>"""
