@echo off
cd /d "%USERPROFILE%\docker"
echo Images to be updated:
dir /a:d /b
echo ------------------------------

echo Updating qbittorrent
cd "qbittorrent"
docker pull qbittorrentofficial/qbittorrent-nox:latest
docker compose down
docker compose up -d
echo qbittorrent updated successfully.
echo ------------------------------

@REM echo Updating jellyfin
@REM cd /d "..\jellyfin"
@REM docker pull jellyfin/jellyfin:latest
@REM docker compose down
@REM docker compose up -d
@REM echo jellyfin updated successfully.
@REM echo ------------------------------

echo Updating jackett
cd /d "..\jackett"
docker pull qmcgaw/gluetun:latest
docker pull lscr.io/linuxserver/jackett:latest
docker pull ghcr.io/flaresolverr/flaresolverr:latest
docker compose down
docker compose up -d
echo jackett updated successfully.
echo ------------------------------

echo Updating seerr
cd /d "..\seerr"
docker pull ghcr.io/seerr-team/seerr:latest
docker compose down
docker compose up -d
echo seerr updated successfully.
echo ------------------------------

echo Updating radarr
cd /d "..\radarr"
docker pull lscr.io/linuxserver/radarr:latest
docker compose down
docker compose up -d
echo radarr updated successfully.
echo ------------------------------

echo Updating sonarr
cd /d "..\sonarr"
docker pull lscr.io/linuxserver/sonarr:latest
docker compose down
docker compose up -d
echo sonarr updated successfully.
echo ------------------------------

echo Updating filebrowser
cd /d "..\filebrowser"
docker pull filebrowser/filebrowser:latest
docker compose down
docker compose up -d
echo filebrowser updated successfully.
echo ------------------------------

echo Updating tailscale
cd /d "..\tailscale"
docker pull tailscale/tailscale:latest
REM Note: plain "down" only - never use "down -v" here. The tailscale-state
REM volume holds the node identity and the advertised-services setting;
REM wiping it forces a re-auth and a re-advertise.
docker compose down
docker compose up -d
echo tailscale updated successfully.
echo ------------------------------

REM ----- Non media-server services -----

echo Updating swarmui
cd /d "..\swarmui"
REM SwarmUI builds from its own source checkout rather than a published image.
REM Never use "down -v" here - the swarmui-* volumes hold the ComfyUI backend,
REM its Python environment, and all settings.
git -C SwarmUI pull
docker compose build
docker compose down
docker compose up -d
echo swarmui updated successfully.
echo ------------------------------

echo Updating comfyui
cd /d "..\comfyui"
REM Tag is pinned: Blackwell needs CUDA 12.8+, and a CUDA change rebuilds the venv.
REM Never use "down -v" here - the comfyui-run volume holds ComfyUI and PyTorch.
docker pull mmartial/comfyui-nvidia-docker:ubuntu24_cuda12.9-latest
docker compose down
docker compose up -d
echo comfyui updated successfully.
echo ------------------------------

docker image prune -f
pause
