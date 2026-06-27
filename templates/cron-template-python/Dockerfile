# =============================================================================
# cron-template-python — scheduled job (Python) via supercronic.
# CLOUD/default image. supercronic vendored (./bin/supercronic) — no network.
# =============================================================================
FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates tzdata \
 && rm -rf /var/lib/apt/lists/*
COPY bin/supercronic /usr/local/bin/supercronic
RUN chmod +x /usr/local/bin/supercronic
WORKDIR /app
# Deps:  COPY requirements.txt ./ && RUN pip install --no-cache-dir -r requirements.txt
COPY crontab job.py ./
CMD ["supercronic", "/app/crontab"]
