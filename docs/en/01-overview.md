# 01 · Overview

A single Docker Compose stack providing the backing services your projects need
during development — MySQL, PostgreSQL, Redis, Memcached, a PHP runtime, and a
full Kafka stack (with Debezium CDC). Each group sits behind a **profile**, so
you start only what a task needs.

On top of the services, an edge **proxy** (nginx-proxy) + **dnsmasq** give every
project a `<name>.test` hostname, and a library of **templates** scaffolds new
projects across many languages and frameworks.

- Services are gated by profiles: `proxy`, `php`, `mysql`, `postgres`, `mongo`,
  `redis`, `memcached`, `kafka`, `phpcacheadmin`, `dbgate`, `drawdb`, `hop`,
  `superset`, `semgrep`, `insighttrack`, `vaultwarden`, `werkyn`, `soketi`,
  `centrifugo`, `mqtt`, `all`.
  Each one is described in detail in
  [13 · Profiles](13-profiles.md).
- `lds up` with no profiles starts every profile whose `LDS_ENABLE_<PROFILE>`
  toggle in `.env` is `true` (defaults: `proxy`, `php`, `mysql`, `dbgate` on).
  Flip a single line (e.g. `LDS_ENABLE_KAFKA=true`) to add a group. The realtime brokers
  (`soketi`, `centrifugo`, `mqtt`) are off by default — start one with
  `lds up <name>` or flip its toggle.
- Everything shares one external network, `lds-network`.
- One wrapper command, `lds`, drives the whole stack (see [04](04-commands.md)).
