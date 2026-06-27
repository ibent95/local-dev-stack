import socket
from http.server import BaseHTTPRequestHandler, HTTPServer

# Native Python web tech: the stdlib http.server (no framework).
PORT = 8000


def page(host: str) -> bytes:
    return (
        "<!doctype html>"
        "<html lang=\"en\"><head><meta charset=\"utf-8\">"
        "<title>web-template-python</title>"
        "<style>body{font:16px/1.6 system-ui,sans-serif;max-width:40rem;margin:4rem auto;padding:0 1rem}</style>"
        "</head><body><h1>web-template-python</h1>"
        "<p>Hello from a Python server-rendered page (http.server).</p>"
        f"<p>Host: <code>{host}</code></p></body></html>"
    ).encode()


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"ok")
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(page(socket.gethostname()))

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    print(f"web-template-python listening on :{PORT}")
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
