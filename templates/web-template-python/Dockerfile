# =============================================================================
# Python web app — live reload via watchfiles, from the shared base lds/python-dev.
# =============================================================================
FROM lds/python-dev:3.12
WORKDIR /app
COPY . .
EXPOSE 8000
CMD ["watchfiles", "python main.py"]
