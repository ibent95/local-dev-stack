# LOCAL dev image — uses the shared lds/php base, which ALREADY bundles
# supercronic (no COPY needed). Source bind-mounted (edit job.php -> next run
# uses it). Deploy uses ./Dockerfile (lean php:8.4-cli-alpine + vendored binary).
FROM lds/php:8.4
WORKDIR /app
CMD ["supercronic", "/app/crontab"]
