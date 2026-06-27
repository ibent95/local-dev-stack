#!/usr/bin/env python3
"""Your scheduled task. Output goes to stdout (lds app logs). Keep it idempotent."""
import datetime
import socket

print(f"[{datetime.datetime.now().isoformat()}] cron-template-python: ran on {socket.gethostname()}", flush=True)

# Backing services are reachable by name on lds-network, e.g.:
#   import pymysql  (add to requirements.txt) -> pymysql.connect(host="mysql", ...)
#   import urllib.request; urllib.request.urlopen("http://my-svc:8080/health")
