# =============================================================================
# dev  : live reload via watchfiles, from the shared base lds/python-dev.
# prod : plain Python on a slim image.
# =============================================================================
FROM lds/python-dev:3.12 AS dev
WORKDIR /app
COPY . .
EXPOSE 8000
CMD ["watchfiles", "python main.py"]

FROM python:3.12-bookworm-slim AS prod
WORKDIR /app
COPY . .
EXPOSE 8000
CMD ["python", "main.py"]
