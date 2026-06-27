# 02 · Prasyarat

- Docker Desktop (atau Docker Engine + Compose v2).
- Port host kosong: 4400–4404 (database & cache), 80, 53 (proxy web + DNS),
  4410–4413 (broker Kafka + backend), 4420–4422 (UI web).
  Ubah di `.env` bila perlu.
- Agar hostname `*.test` ter-resolve di host, arahkan DNS adapter jaringan
  Windows ke `127.0.0.1` (container `dns` menjawab `*.test` dan meneruskan
  sisanya ke upstream), atau pakai `lds hosts-sync`. Setup lengkap + catatan:
  [14 · Meresolusi `*.test` (DNS)](14-dns.md).
