# LOCAL dev image — uses the shared lds/python-dev base (run `lds build-bases`).
# Source bind-mounted (edit job.py -> next run uses it). Deploy uses ./Dockerfile.
FROM lds/python-dev:3.12
# supercronic ships in the lds/python-dev base image (no COPY needed).
WORKDIR /app
# Deps still install at build:  COPY requirements.txt ./ && RUN pip install --no-cache-dir -r requirements.txt
CMD ["supercronic", "/app/crontab"]
