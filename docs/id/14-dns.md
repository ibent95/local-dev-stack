# 14 · Meresolusi `*.test` (DNS)

Agar `http://<nama>.test` terbuka di browser, OS host harus meresolusi
`<nama>.test` ke `127.0.0.1` (tempat proxy mendengarkan). Ada dua cara:

| Pendekatan | Mencakup | Cocok untuk |
|------------|----------|-------------|
| **DNS adapter → `127.0.0.1`** (container `dns`) | **semua** `*.test`, kini + nanti, wildcard | pemakaian harian — set sekali, lupakan |
| **`lds hosts-sync`** (berkas hosts) | hanya nama yang ditulisnya (folder PHP + UI stack) | coba cepat / mesin terkunci yang tak bisa ubah DNS |

Berkas hosts **tidak bisa wildcard**, jadi setiap host `.test` baru perlu
sync ulang. Mengarahkan DNS adapter ke container `dns` adalah opsi wildcard dan
yang sebaiknya dipilih.

---

## Opsi A — arahkan DNS adapter ke `127.0.0.1` (disarankan)

Container `dns` (dnsmasq, dijalankan profile `proxy`/`php`) menjawab `*.test` →
`127.0.0.1` dan **meneruskan sisanya ke upstream** (`8.8.8.8`, `1.1.1.1`),
sehingga DNS internet normal tetap jalan.

> ⚠️ **Catatan penting:** begitu DNS adapter Anda `127.0.0.1`, *semua* resolusi
> nama lewat container itu. Ia hanya menjawab selama container `dns` stack
> **berjalan** — jika Anda `lds down`/`lds stop`, internet "berhenti resolve"
> sampai Anda menjalankannya lagi atau mengembalikan setelan DNS. Biarkan
> `proxy`/`php` tetap hidup saat bekerja, atau pakai Opsi B untuk pemakaian
> sesekali.

### Windows — Settings (GUI)

1. **Settings → Network & Internet** → adapter aktif (**Wi-Fi** atau
   **Ethernet**).
2. Cari **DNS server assignment** → **Edit**.
3. Ubah **Automatic (DHCP)** → **Manual**, aktifkan **IPv4**.
4. **Preferred DNS:** `127.0.0.1`. Biarkan Alternate kosong. **Save**.
5. Bersihkan cache agar jawaban lama hilang:
   ```
   ipconfig /flushdns
   ```

### Windows — PowerShell (jalankan sebagai Administrator)

```powershell
# Lihat adapter dan pilih yang "Up":
Get-NetAdapter

# Arahkan DNS-nya ke container dns (ganti "Wi-Fi" dengan nama adapter Anda):
Set-DnsClientServerAddress -InterfaceAlias "Wi-Fi" -ServerAddresses 127.0.0.1
Clear-DnsClientCache
```

**Kembalikan** ke DNS otomatis (DHCP) kapan saja:

```powershell
Set-DnsClientServerAddress -InterfaceAlias "Wi-Fi" -ResetServerAddresses
Clear-DnsClientCache
```

### Verifikasi

```powershell
nslookup app.test 127.0.0.1     # -> Address: 127.0.0.1
ping centrifugo.test            # -> balasan dari 127.0.0.1
```

> `nslookup app.test` *tanpa* `127.0.0.1` di belakang menanyakan DNS normal Anda,
> bukan container — jadi selalu sertakan `127.0.0.1` saat menguji, atau cukup buka
> URL-nya di browser.

### Port 53 harus bebas

Container `dns` mempublikasikan UDP/TCP **53** di host. Jika ada yang sudah
memakainya (jarang di Windows desktop; kadang Internet Connection Sharing atau
resolver lokal), `lds up` gagal bind. Bebaskan, atau ubah `DNS_HOST_PORT` di
`.env` — meski resolver OS selalu menanyakan port 53, jadi port non-53 hanya
berguna bila Anda mengarahkan alat tertentu ke sana. Cara termudah: hentikan
apa pun yang memakai 53.

---

## Opsi B — `lds hosts-sync` (fallback berkas hosts)

Tanpa ubah DNS; menulis baris `127.0.0.1 <nama>.test` ke berkas hosts. Perlu
shell **Administrator** (mengedit `C:\Windows\System32\drivers\etc\hosts`).

```
lds hosts-sync
```

Ia menulis satu entri per folder proyek PHP di bawah `PHP_PROJECTS_PATH`, plus
UI web / dashboard broker stack: `cache.test`, `db.test`, `centrifugo.test`,
`mqtt.test`, `ws.test`. **Jalankan ulang setiap kali menambah proyek** — berkas
hosts tak punya wildcard, jadi nama baru tidak tercakup sampai sync lagi. Entri
untuk service yang profilnya mati tidak masalah (proxy hanya belum punya tujuan
ke sana).

---

## macOS / Linux (singkat)

- **DNS adapter:** set DNS network service ke `127.0.0.1` (macOS: *System
  Settings → Network → Details → DNS*; Linux: NetworkManager / `resolv.conf` /
  `systemd-resolved`, tergantung distro).
- **Berkas hosts:** `sudo ./lds.sh hosts-sync` menulis entri yang sama ke
  `/etc/hosts`.

Catatan wildcard dan "biarkan container `dns` berjalan" berlaku sama di setiap OS.
