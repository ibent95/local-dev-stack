# 02 · Prasyarat

- Docker Desktop (atau Docker Engine + Compose v2).
- Port host kosong: 4400–4409 (database & cache), 80, 53 (proxy web + DNS),
  4420–4424 (stack Kafka), 4440–4444 (broker realtime), 4451 (Trino),
  4500–4543 (UI web & tool).
  Ubah di `.env` bila perlu.
- Agar hostname `*.test` ter-resolve di host, arahkan DNS adapter jaringan
  Windows ke `127.0.0.1` (container `dns` menjawab `*.test` dan meneruskan
  sisanya ke upstream), atau pakai `lds hosts-sync`. Setup lengkap + catatan:
  [14 · Meresolusi `*.test` (DNS)](14-dns.md).
