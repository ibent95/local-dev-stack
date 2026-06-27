# =============================================================================
# Base image: lds/python-dev — Python + watchfiles (live reload for plain apps).
# =============================================================================
# Docker Hardened Image (DHI) dev flavor — Python + shell + pip.
ARG DHI_REGISTRY=dhi.io
ARG PYTHON_VERSION=3.14
FROM ${DHI_REGISTRY}/python:${PYTHON_VERSION}-alpine3.24-dev

# DHI defaults to a non-root user; the global pip install + COPY below need root.
USER root

# DHI's python defaults pip to its curated index (no watchfiles), so pull from
# upstream PyPI — same as adding upstream apk/apt repos for the other bases.
# (watchfiles ships a cp314 musllinux wheel, so this is a wheel install, no build.)
RUN pip install --no-cache-dir --index-url https://pypi.org/simple watchfiles

# supercronic — container cron for cron-* templates (vendored amd64 from assets/,
# no network download; this base builds from the repo root — see docker-bake.hcl).
COPY assets/supersonic/v0.2.46/supercronic-linux-amd64 /usr/local/bin/supercronic
RUN chmod +x /usr/local/bin/supercronic

WORKDIR /app
