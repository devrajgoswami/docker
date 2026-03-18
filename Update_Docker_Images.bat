@echo off
cd /d "%USERPROFILE%\docker"
echo Images to be updated:
dir /a:d /b
echo ------------------------------

echo Updating jellyfin
cd jellyfin
docker pull jellyfin/jellyfin:latest
docker compose down
docker compose up -d
echo jellyfin updated successfully.
echo ------------------------------

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

echo Updating qbittorrent
cd /d "..\qbittorrent"
docker pull qbittorrentofficial/qbittorrent-nox:latest
docker compose down
docker compose up -d
echo qbittorrent updated successfully.
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
docker image prune -f
pause
