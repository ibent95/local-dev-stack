# 08 · Template

Template ada di `templates/`, dinamai menurut **peran** dan **teknologi**:

- `svc-template-<x>` — API (mengembalikan JSON).
- `web-template-<x>` — aplikasi web ber-UI (server-rendered atau SPA).

Dan dibagi **native vs framework**:

- **Native** (teknologi web bawaan bahasa): `go` (net/http), `node` (http
  module), `python` (http.server), `java` (Servlet); `rust` memakai axum
  (tidak ada HTTP stdlib).
- **Framework** (template terpisah): `springboot`, `express`, `flask`,
  `fastapi`, `django`, `laravel`, `angular`, `react` (+ lainnya bila ditambah).

Sebagian besar berpasangan `svc-`+`web-`. Template **code-included** langsung
jalan; yang **scaffolded** menghasilkan framework asli ke `./src` lewat CLI-nya
saat pertama kali (perintah ada di README tiap template).

Lihat `templates/README.md` untuk tabel lengkap dan README tiap template.
