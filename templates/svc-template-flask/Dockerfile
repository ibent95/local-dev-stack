# =============================================================================
# Flask — dev (flask run --debug, auto-reload) from lds/python-dev.
# =============================================================================
FROM lds/python-dev:3.12
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
ENV FLASK_APP=app.py FLASK_DEBUG=1
CMD ["flask", "run", "--host=0.0.0.0", "--port=8000"]
