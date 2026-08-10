# Scanner image for code-review-graph (tirth8205/code-review-graph).
# Built locally (lds/crg:<CRG_VERSION>) — upstream publishes no Docker image.
# `lds tools crg <path>` runs this image over a mounted repo: it builds the
# Tree-sitter graph inside the repo (.code-review-graph/) and exports the
# interactive HTML report for the crg.test viewer.
FROM python:3.12-slim

# git: CRG reads VCS state for diff/co-change analysis; ca-certificates for the
# pip install below (debian slim has none by default).
RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir "code-review-graph==${CRG_VERSION:-2.3.7}"

WORKDIR /src
ENTRYPOINT ["code-review-graph"]
CMD ["--help"]
