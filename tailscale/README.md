# Tailscale on Windows / Docker Desktop

Gives every self-hosted app its own HTTPS hostname reachable from anywhere,
with no port forwarding and no exposure to the public internet.

| App | LAN URL (unchanged) | Tailscale URL |
|---|---|---|
| Jellyfin | `http://<pc-ip>:8096` | `https://jellyfin.saola-buri.ts.net` |
| qBittorrent | `http://<pc-ip>:8080` | `https://qbittorrent.saola-buri.ts.net` |
| Sonarr | `http://<pc-ip>:8989` | `https://sonarr.saola-buri.ts.net` |
| Radarr | `http://<pc-ip>:7878` | `https://radarr.saola-buri.ts.net` |
| Seerr | `http://<pc-ip>:5055` | `https://seerr.saola-buri.ts.net` |
| Filebrowser | `http://<pc-ip>:8082` | `https://filebrowser.saola-buri.ts.net` |

Certificates are real Let's Encrypt certs, so phones and browsers show no warnings.

---

## How this differs from the original (Linux) config

This was adapted from a Linux server setup. Docker Desktop on Windows runs
containers inside a Linux VM, not on the Windows host, so two things changed:

| | Original (Linux) | This config (Windows) |
|---|---|---|
| Networking | `network_mode: host` | default bridge |
| WireGuard | kernel mode, needs `/dev/net/tun` + `NET_ADMIN` | `TS_USERSPACE=true` |
| Proxy target | `http://127.0.0.1:<port>` | `http://host.docker.internal:<port>` |
| State storage | `./state` bind mount | named volume `tailscale-state` |
| Helper scripts | bash + `jq` | PowerShell (`.ps1`) |

`host.docker.internal` points at the Windows host, where all your app ports are
published — that is how the Tailscale container reaches Jellyfin, Sonarr, etc.

---

## Files

```
tailscale/
├── docker-compose.yml            # the container
├── .env                          # secrets (do not commit)
├── .env.example                  # template
├── serve-config.json             # which hostname proxies to which port
└── scripts/
    ├── policy.hujson             # ACL / tag / auto-approver policy
    ├── advertise-services.ps1    # one-time (and after adding a new app)
    └── push-policy.ps1           # optional: push policy.hujson via API
```

---

## Setup

### 1. Create a Tailscale account

Sign up at <https://login.tailscale.com/start>. Your tailnet name appears in the
admin console — this config assumes **`saola-buri.ts.net`**. If yours differs,
update every hostname in `serve-config.json`.

### 2. Turn on MagicDNS and HTTPS

<https://login.tailscale.com/admin/dns>

- **MagicDNS** → ON
- **HTTPS Certificates** → ON

Both are required; without HTTPS certs the `.ts.net` URLs will not get certificates.

### 3. Apply the ACL policy

Open <https://login.tailscale.com/admin/acls/file>, replace the contents with
`scripts/policy.hujson`, and save.

This defines `tag:server` (required to host Services) and auto-approves the six
services so you do not have to click approve for each one.

### 4. Create an auth key

<https://login.tailscale.com/admin/settings/keys> → **Generate auth key**

| Setting | Value |
|---|---|
| Description | Docker Tailscale on devraj-pc |
| Reusable | ON |
| Ephemeral | OFF |
| Tags | `tag:server` |

Copy the `tskey-auth-...` value.

### 5. Fill in `.env`

Edit `tailscale\.env`:

```env
TS_AUTHKEY=tskey-auth-xxxxxxxxxxxxxxxxxxxx
```

Leave the `OAUTH_*` lines as-is unless you want to push ACL changes from the
command line later.

### 6. Define the services in the admin console

<https://login.tailscale.com/admin/services> → **Define a service**, once per app.

| Name | Endpoint |
|---|---|
| `jellyfin` | `tcp:443` |
| `qbittorrent` | `tcp:443` |
| `sonarr` | `tcp:443` |
| `radarr` | `tcp:443` |
| `seerr` | `tcp:443` |
| `filebrowser` | `tcp:443` |

They will show **Needs configuration** until step 8.

### 7. Start the container

```powershell
cd C:\Users\devra\docker\tailscale
docker compose up -d
docker logs tailscale --tail 30
```

Look for `Success.` and `active login: devraj-pc.saola-buri.ts.net`.

### 8. Advertise the services

This binds each service to this machine. It is a **one-time** step — the setting
is written into the `tailscale-state` volume and survives restarts, container
recreates and reboots. You only need to re-run it after adding a new app, or if
you ever wipe the state volume with `docker compose down -v`.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\advertise-services.ps1
```

All six should now show `devraj-pc` as host in the admin console.

### 9. Install Tailscale on your other devices

- Android: <https://play.google.com/store/apps/details?id=com.tailscale.ipn>
- iOS: App Store → "Tailscale"
- Windows/macOS: <https://tailscale.com/download>

Sign in with the same account. Then, with mobile data on (not home WiFi), open
`https://jellyfin.saola-buri.ts.net`.

---

## Day-to-day

```powershell
cd C:\Users\devra\docker\tailscale

# status
docker exec tailscale tailscale --socket=/tmp/tailscaled.sock status
docker exec tailscale tailscale --socket=/tmp/tailscaled.sock serve status

# logs
docker logs tailscale --tail 50

# update (advertisement persists via the state volume - no need to re-advertise)
docker compose pull
docker compose up -d
```

### Add another app

1. Add a `svc:<name>` block to `serve-config.json` pointing at
   `http://host.docker.internal:<port>`
2. Add `"svc:<name>": ["tag:server"]` to `autoApprovers` in `scripts/policy.hujson`
   and save it in the admin console (or run `push-policy.ps1`)
3. Define the service in the admin console with endpoint `tcp:443`
4. `docker compose up -d --force-recreate`
5. Add the name to the `$services` list in `scripts/advertise-services.ps1`, then run it

### Share Jellyfin with a friend (external user)

**Tailscale Services cannot be shared.** Sharing a machine shares only that
machine — services, subnet routes and tags are all stripped. So
`jellyfin.saola-buri.ts.net` will never work for an external user, no matter
what you do.

The workaround is the machine-level block at the bottom of `serve-config.json`,
which serves selected apps on the machine's own hostname:

| App | URL for external users |
|---|---|
| Jellyfin | `https://devraj-pc.saola-buri.ts.net:8443` |
| Filebrowser | `https://devraj-pc.saola-buri.ts.net:8444` |

To share:

1. Admin console → [Machines](https://login.tailscale.com/admin/machines) →
   `devraj-pc` → **Share**, and send the invite link
2. Your friend accepts, installs Tailscale, and must have **MagicDNS enabled**
   on their own tailnet
3. They open the URL above — `https://` and the port are both required, and the
   full FQDN must be used; the short name will not resolve for them
4. Give them an account in the app itself (Tailscale only controls network access)

To expose one more app to external users, add another port to the machine-level
`TCP`/`Web` blocks in `serve-config.json`, add that port to the
`autogroup:shared` grant in `scripts/policy.hujson`, then restart the container.

The `autogroup:shared` grant restricts external users to those ports only, so
they cannot reach qBittorrent, Sonarr, Radarr or Seerr. Never use
`"src": ["*"]` in a grant — it matches invited external users too.

---

## Notes and gotchas

**Accessing service URLs from this PC itself does not work.** Tailscale Services
cannot be reached from the machine that hosts them. Keep using `http://localhost:8096`
etc. locally.

**Windows Firewall.** If the container starts fine but the URLs return a 502, the
Windows firewall may be blocking the Docker VM from reaching host ports. Allow
inbound traffic on the app ports for the `vEthernet (WSL)` / Docker network profile.

**Docker Desktop must be running.** The Tailscale node is only online while
Docker Desktop is running, and Docker Desktop only starts after you sign in to
Windows. Enable *Start Docker Desktop when you sign in* in Docker Desktop
settings, and set Windows sleep to *Never* if you want 24/7 access. This is the
only thing that actually breaks after a reboot.

**Jackett is intentionally excluded.** It runs through the gluetun VPN container
(`network_mode: service:gluetun`), so exposing it over Tailscale would route
traffic oddly. Add it later if you want it.

**Auth keys expire** (90 days by default), but that only affects *first*
registration. Once registered, the node identity lives in the `tailscale-state`
volume and an expired key does not matter. Because the node is tagged
`tag:server`, its node key does not expire either.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Container restart-loops | `docker logs tailscale` — usually a bad/expired `TS_AUTHKEY` |
| `403 ... not have enough permissions` | Auth key was not created with `tag:server` |
| Services stuck on "Needs configuration" | Run `advertise-services.ps1` |
| `502 Bad Gateway` on a service URL | Target app is down, or wrong port in `serve-config.json`, or firewall |
| Cert warning in browser | HTTPS Certificates not enabled in admin console DNS settings |
| Want a clean slate | `docker compose down -v` (wipes state), remove the machine in the admin console, then start over from step 7 |
