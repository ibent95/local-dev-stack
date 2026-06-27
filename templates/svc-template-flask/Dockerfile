# =============================================================================
# Flask — dev (flask run --debug, auto-reload) from lds/python-dev; prod = gunicorn.
# =============================================================================
FROM lds/python-dev:3.12 AS dev
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
ENV FLASK_APP=app.py FLASK_DEBUG=1
CMD ["flask", "run", "--host=0.0.0.0", "--port=8000"]

FROM python:3.12-bookworm-slim AS prod
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["gunicorn", "-b", "0.0.0.0:8000", "app:app"]
