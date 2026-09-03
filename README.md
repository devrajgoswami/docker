# Docker Stacks

Self-hosted services running on Docker Desktop for Windows with the WSL 2 backend.
Each service lives in its own folder with its own `docker-compose.yml` and a local
`config/` bind mount, so services can be started, stopped, and updated independently.

The stacks fall into two unrelated groups:

| Group | Services | Purpose |
|---|---|---|
| [Home Media Server](#home-media-server) | qBittorrent, Jackett, FlareSolverr, Gluetun, Radarr, Sonarr, Seerr, File Browser, Tailscale | Acquire, organise, and stream media |
| [Other Services](#other-services) | SwarmUI, ComfyUI | Everything unrelated to the media server |

Shared setup, update, and security guidance is in
[Common operations](#common-operations).

---

## Home Media Server

Media lives on `E:\Media`; torrent downloads land in `E:\Media\TorrentDownloads`.
Remote access is handled by Tailscale — no ports are forwarded on the router.

> **Jellyfin is installed natively on Windows, not in Docker.** It was moved out
> because NVIDIA hardware decoding did not work properly in the container. Tailscale
> still proxies it, reaching the host at `host.docker.internal:8096`.

### Services

| Service | Folder | Image | Local URL | Purpose |
|---|---|---|---|---|
| Jellyfin | native install (no compose file) | — | http://localhost:8096 | Media server (NVIDIA hardware transcoding) |
| qBittorrent | [qbittorrent](qbittorrent/docker-compose.yml) | `qbittorrentofficial/qbittorrent-nox` | http://localhost:8080 | Torrent client |
| Jackett | [jackett](jackett/docker-compose.yml) | `lscr.io/linuxserver/jackett` | http://localhost:9117 | Indexer proxy (behind VPN) |
| FlareSolverr | [jackett](jackett/docker-compose.yml) | `ghcr.io/flaresolverr/flaresolverr` | http://localhost:8191 | Cloudflare challenge solver (behind VPN) |
| Gluetun | [jackett](jackett/docker-compose.yml) | `qmcgaw/gluetun` | — | WireGuard VPN gateway for Jackett/FlareSolverr |
| Radarr | [radarr](radarr/docker-compose.yml) | `lscr.io/linuxserver/radarr` | http://localhost:7878 | Movie automation |
| Sonarr | [sonarr](sonarr/docker-compose.yml) | `lscr.io/linuxserver/sonarr` | http://localhost:8989 | TV automation |
| Seerr | [seerr](seerr/docker-compose.yml) | `ghcr.io/seerr-team/seerr` | http://localhost:5055 | Request portal |
| File Browser | [filebrowser](filebrowser/docker-compose.yml) | `filebrowser/filebrowser` | http://localhost:8082 | Web file manager for `E:\Media` |
| Tailscale | [tailscale](tailscale/docker-compose.yml) | `tailscale/tailscale` | — | HTTPS reverse proxy + remote access |

### Port map

| Port | Service |
|---|---|
| 5055 | Seerr |
| 6881 (TCP/UDP) | qBittorrent peer traffic |
| 6882 (TCP/UDP) | Gluetun peer traffic |
| 7878 | Radarr |
| 8080 | qBittorrent Web UI |
| 8082 | File Browser |
| 8096 | Jellyfin |
| 8191 | FlareSolverr |
| 8989 | Sonarr |
| 9117 | Jackett |

### Architecture

```mermaid
flowchart LR
    User[Browser / Phone] -->|HTTPS via tailnet| TS[Tailscale]
    TS --> Jellyfin
    TS --> Seerr
    TS --> Radarr
    TS --> Sonarr
    TS --> qBittorrent
    TS --> FileBrowser

    Seerr --> Radarr
    Seerr --> Sonarr
    Radarr --> Jackett
    Sonarr --> Jackett
    Radarr --> qBittorrent
    Sonarr --> qBittorrent
    Jackett -->|network_mode: service:gluetun| Gluetun
    FlareSolverr -->|network_mode: service:gluetun| Gluetun
    Gluetun -->|WireGuard| Internet
    qBittorrent --> Downloads[(E:\Media\TorrentDownloads)]
    Downloads --> Media[(E:\Media)]
    Media --> Jellyfin
```

Jackett and FlareSolverr have no network stack of their own — they share Gluetun's,
so all indexer traffic exits through the WireGuard tunnel. If Gluetun stops, those
two containers lose connectivity entirely (fail-closed).

### First-run configuration

1. **Jellyfin** — complete the setup wizard, add libraries from `/Media`.
2. **Jackett** — add indexers, copy the API key.
3. **qBittorrent** — set the download path to `/Media/TorrentDownloads`. The initial
   admin password is printed in the container logs on first start.
4. **Radarr / Sonarr** — add Jackett as an indexer and qBittorrent as the download
   client, then point the root folder at `/Media`.
5. **Seerr** — connect it to Jellyfin, Radarr, and Sonarr.
6. **Tailscale** — follow [tailscale/README.md](tailscale/README.md).

Because Jackett runs on Gluetun's network namespace, Radarr and Sonarr must reach it
via the host (`http://host.docker.internal:9117`), not by container name.

### Remote access

Tailscale publishes each app under its own HTTPS hostname with a real Let's Encrypt
certificate, so nothing is exposed to the public internet:

| App | Tailscale URL |
|---|---|
| Jellyfin | `https://jellyfin.<tailnet>.ts.net` |
| qBittorrent | `https://qbittorrent.<tailnet>.ts.net` |
| Sonarr | `https://sonarr.<tailnet>.ts.net` |
| Radarr | `https://radarr.<tailnet>.ts.net` |
| Seerr | `https://seerr.<tailnet>.ts.net` |
| File Browser | `https://filebrowser.<tailnet>.ts.net` |

Routing is defined in [tailscale/serve-config.json](tailscale/serve-config.json).
Full setup instructions are in [tailscale/README.md](tailscale/README.md).

---

## Other Services

Anything not part of the media server lives here, whether or not it is AI related. A
service only gets its own top-level section if it grows large enough to need one.

| Service | Folder | Image | Local URL | Purpose |
|---|---|---|---|---|
| SwarmUI | [swarmui](swarmui/docker-compose.yml) | built from source | http://localhost:7801 | **Primary image generation and editing UI** |
| ComfyUI | [comfyui](comfyui/docker-compose.yml) | `mmartial/comfyui-nvidia-docker` | http://localhost:8188 | Node-graph editor for custom workflows |

### Image generation

**Start at SwarmUI: http://localhost:7801.** It gives a prompt box, a model dropdown,
and a built-in image editor for inpainting and photo edits, with its own ComfyUI
backend doing the work. Full instructions are in [swarmui/README.md](swarmui/README.md).

ComfyUI remains available at http://localhost:8188 for hand-built node graphs. The two
**share one models folder** (`comfyui/basedir/models`), so a model downloaded in either
appears in both and the 16 GB of FLUX weights is stored once.

| Port | Service |
|---|---|
| 7801 | SwarmUI |
| 8188 | ComfyUI |

Points that differ from the media services:

- **Both are bound to `127.0.0.1`, not `0.0.0.0`.** Neither has authentication, so
  neither is published to the tailnet. Add them to
  [tailscale/serve-config.json](tailscale/serve-config.json) only if you accept that
  anyone on the tailnet gets unauthenticated access to the GPU and filesystem.
- **No `config/` directories.** Application code and Python environments live in named
  volumes, because a Python venv on a Windows bind mount is slow and breaks on
  permissions. The parts worth backing up are `comfyui/basedir/` (models, outputs) and
  `swarmui/Output/`.
- **Both containers run as UID/GID 1000** and refuse to start if a mount is owned by
  anyone else. New Docker volumes start root-owned; each service README documents the
  `chown` fix.
- **SwarmUI builds from source.** There is no published image, so `swarmui/SwarmUI/` is
  an upstream git clone, gitignored and compiled by `docker compose build`.
- **They share models but not VRAM.** Running large generations in both at once will
  contend for the 16 GB on the GPU. Use one at a time.
- **Model weights are not included.** FLUX.1-dev requires a Hugging Face account and
  licence acceptance; see [comfyui/README.md](comfyui/README.md).

---

## Common operations

### Prerequisites

- Windows with [Docker Desktop](https://www.docker.com/products/docker-desktop/) and the WSL 2 backend
- An `E:\Media` drive for the media stack (or edit the bind mounts in each compose file)
- A WireGuard VPN subscription for Gluetun
- A Tailscale account for remote access
- An NVIDIA GPU with a current driver, required by ComfyUI and by Jellyfin's native
  hardware transcoding. Verify container GPU access with:
  ```powershell
  docker run --rm --gpus all nvidia/cuda:12.8.0-base-ubuntu22.04 nvidia-smi
  ```

### Getting started

Start an individual service:

```powershell
cd C:\Users\devra\docker\qbittorrent
docker compose up -d
```

Start everything:

```powershell
cd C:\Users\devra\docker
Get-ChildItem -Directory | ForEach-Object { docker compose -f "$($_.FullName)\docker-compose.yml" up -d }
```

View logs / stop a service:

```powershell
docker compose logs -f
docker compose down
```

### Updating

[Update_Docker_Images.bat](Update_Docker_Images.bat) pulls the latest image for every
service, recreates the containers, and prunes dangling images:

```powershell
.\Update_Docker_Images.bat
```

Tailscale's persistent state volume is preserved during updates so its node identity
and advertised services are not lost. Never run `docker compose down -v` in the
`tailscale` folder — the `tailscale-state` volume holds the node identity and
advertised services; removing it forces a re-auth.

The same applies to `comfyui`: `down -v` would delete the `comfyui-run` volume and
force a full multi-GB reinstall of ComfyUI and PyTorch.

#### qBittorrent fails to start after an update

qBittorrent occasionally refuses to start or comes back with a broken Web UI after its
image is updated, because stale state in `qbittorrent/config/` (lock file, IPC socket,
cached data) does not survive the version change.
[qbittorrent/reset-qbittorrent-config.bat](qbittorrent/reset-qbittorrent-config.bat)
fixes this by wiping that state while keeping the settings:

```powershell
.\qbittorrent\reset-qbittorrent-config.bat
```

It stops the container, deletes everything under `qbittorrent/config/` except
`config/qBittorrent/config/qBittorrent.conf`, restores that file, and starts the
container again. Because `qBittorrent.conf` is preserved, the Web UI password, ports,
and download paths stay intact; torrents in `data/BT_backup` are **not** preserved and
have to be re-added.

### Security notes

- **Secrets live in `.env` files, never in compose.** [.gitignore](.gitignore) excludes
  every `.env` (and the `config/`, `cache/`, `logs/` state directories) while keeping the
  `.env.example` templates tracked. Current secret files:

  | File | Template | Holds |
  |---|---|---|
  | `jackett/.env` | [jackett/.env.example](jackett/.env.example) | WireGuard private + preshared key |
  | `tailscale/.env` | [tailscale/.env.example](tailscale/.env.example) | Tailscale auth key |

- **`PUID=0` / `privileged: true`** in the Radarr, Sonarr, and qBittorrent compose files
  run those containers as root with elevated privileges. Prefer a non-root UID/GID
  (for example `1000:1000`, as File Browser and ComfyUI use) and drop `privileged`
  unless a specific feature requires it.
- **Set a strong password on every web UI**, especially qBittorrent and File Browser,
  since they are reachable over the tailnet.
- **Keep ComfyUI on `127.0.0.1`** unless you add authentication in front of it.

### Layout

```
docker/
├── Update_Docker_Images.bat   # pull + recreate every service
├── comfyui/                   # ComfyUI + FLUX.1-dev, shared models folder
├── filebrowser/
├── jackett/                   # gluetun + jackett + flaresolverr
├── qbittorrent/               # incl. reset-qbittorrent-config.bat
├── radarr/
├── seerr/
├── sonarr/
├── swarmui/                   # primary image generation UI (not media related)
└── tailscale/
```

Each media service folder holds a `docker-compose.yml` and a `config/` directory that
is bind-mounted into the container. Those `config/` directories are the ones worth
backing up, along with `comfyui/basedir/` and `swarmui/Output/`.

