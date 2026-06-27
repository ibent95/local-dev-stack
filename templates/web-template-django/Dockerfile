# =============================================================================
# Django — dev (manage.py runserver, auto-reload) from lds/python-dev.
# prod = gunicorn on the scaffolded project's wsgi (project name: config).
# The Django project itself is generated into ./src (see README).
# =============================================================================
FROM lds/python-dev:3.12 AS dev
WORKDIR /app
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt
EXPOSE 8000
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]

FROM python:3.12-bookworm-slim AS prod
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY src/ /app/
EXPOSE 8000
CMD ["gunicorn", "-b", "0.0.0.0:8000", "config.wsgi:application"]
