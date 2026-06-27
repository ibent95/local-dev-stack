import json
import socket
from http.server import BaseHTTPRequestHandler, HTTPServer

# Native Python web tech: the stdlib http.server (no framework).
PORT = 8000


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"ok")
            return
        # Backing services on lds-network: mysql:3306 postgres:5432 redis:6379 ...
        body = json.dumps({
            "service": "svc-template-python",
            "message": "Hello from Python (http.server)",
            "hostname": socket.gethostname(),
        }).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    print(f"svc-template-python listening on :{PORT}")
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
