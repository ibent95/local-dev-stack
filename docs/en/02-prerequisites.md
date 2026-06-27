# 02 · Prerequisites

- Docker Desktop (or Docker Engine + Compose v2).
- Free host ports: 4400–4404 (databases & caches), 80, 53 (web proxy + DNS),
  4410–4413 (Kafka broker + backends), 4420–4422 (web UIs).
  Change any of them in `.env`.
- For `*.test` hostnames to resolve on the host, point your Windows network
  adapter's DNS at `127.0.0.1` (the `dns` container answers `*.test` and
  forwards everything else upstream), or use `lds hosts-sync`. Full setup +
  caveats: [14 · Resolving `*.test` (DNS)](14-dns.md).
