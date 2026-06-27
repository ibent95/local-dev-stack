# 14 · Resolving `*.test` (DNS)

For `http://<name>.test` to open in your browser, the host OS has to resolve
`<name>.test` to `127.0.0.1` (where the proxy listens). There are two ways:

| Approach | Covers | Best for |
|----------|--------|----------|
| **Adapter DNS → `127.0.0.1`** (the `dns` container) | **every** `*.test`, current + future, wildcard | daily use — set once, never touch again |
| **`lds hosts-sync`** (hosts file) | only the names it writes (PHP folders + stack UIs) | quick try / locked-down machines where you can't change DNS |

The hosts file **cannot do wildcards**, so every new `.test` host needs a
re-sync. Pointing your adapter's DNS at the `dns` container is the wildcard
option and the one to prefer.

---

## Option A — point your adapter's DNS at `127.0.0.1` (recommended)

The `dns` container (dnsmasq, started by the `proxy`/`php` profile) answers
`*.test` → `127.0.0.1` and **forwards everything else upstream** (`8.8.8.8`,
`1.1.1.1`), so normal internet DNS keeps working.

> ⚠️ **Important caveat:** once your adapter's DNS is `127.0.0.1`, *all* name
> resolution goes through that container. It only answers while the stack's
> `dns` container is **running** — if you `lds down`/`lds stop` the stack, the
> internet "stops resolving" until you start it again or revert the DNS setting.
> Keep `proxy`/`php` up while you work, or use Option B for casual use.

### Windows — Settings (GUI)

1. **Settings → Network & Internet** → your active adapter (**Wi-Fi** or
   **Ethernet**).
2. Find **DNS server assignment** → **Edit**.
3. Switch **Automatic (DHCP)** → **Manual**, toggle **IPv4** on.
4. **Preferred DNS:** `127.0.0.1`. Leave Alternate blank. **Save**.
5. Flush the cache so old answers don't linger:
   ```
   ipconfig /flushdns
   ```

### Windows — PowerShell (run as Administrator)

```powershell
# See your adapters and pick the one that's "Up":
Get-NetAdapter

# Point its DNS at the dns container (replace "Wi-Fi" with your adapter name):
Set-DnsClientServerAddress -InterfaceAlias "Wi-Fi" -ServerAddresses 127.0.0.1
Clear-DnsClientCache
```

**Revert** to automatic (DHCP) DNS at any time:

```powershell
Set-DnsClientServerAddress -InterfaceAlias "Wi-Fi" -ResetServerAddresses
Clear-DnsClientCache
```

### Verify

```powershell
nslookup app.test 127.0.0.1     # -> Address: 127.0.0.1
ping centrifugo.test            # -> replies from 127.0.0.1
```

> `nslookup app.test` *without* the trailing `127.0.0.1` queries your normal DNS
> server, not the container — so always pass `127.0.0.1` when testing, or just
> open the URL in the browser.

### Port 53 must be free

The `dns` container publishes UDP/TCP **53** on the host. If something already
owns it (rare on desktop Windows; sometimes Internet Connection Sharing or a
local resolver), `lds up` will fail to bind. Free it, or change `DNS_HOST_PORT`
in `.env` — though the OS resolver always queries port 53, so a non-53 port only
works if you point a tool at it explicitly. Easiest fix is to stop whatever holds
53.

---

## Option B — `lds hosts-sync` (hosts-file fallback)

No DNS changes; writes `127.0.0.1 <name>.test` lines into the hosts file. Needs
an **Administrator** shell (it edits `C:\Windows\System32\drivers\etc\hosts`).

```
lds hosts-sync
```

It writes one entry per PHP project folder under `PHP_PROJECTS_PATH`, plus the
stack web UIs / broker dashboards: `cache.test`, `db.test`, `centrifugo.test`,
`mqtt.test`, `ws.test`. **Re-run it whenever you add a project** — the hosts file
has no wildcard, so new names aren't covered until you sync again. Entries for a
service whose profile is off are harmless (the proxy just has nothing to route
there yet).

---

## macOS / Linux (brief)

- **Adapter DNS:** set the network service's DNS to `127.0.0.1` (macOS: *System
  Settings → Network → Details → DNS*; Linux: NetworkManager / `resolv.conf` /
  `systemd-resolved`, distro-dependent).
- **Hosts file:** `sudo ./lds.sh hosts-sync` writes the same entries into
  `/etc/hosts`.

The wildcard caveat and "keep the `dns` container running" note apply the same
way on every OS.
