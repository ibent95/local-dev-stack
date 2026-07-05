# =============================================================================
# Django — dev (manage.py runserver, auto-reload) from lds/python-dev.
# The Django project itself is generated into ./src (see README).
# =============================================================================
FROM lds/python-dev:3.12
WORKDIR /app
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt
EXPOSE 8000
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
