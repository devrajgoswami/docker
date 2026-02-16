@echo off
cd /d "%USERPROFILE%\docker"
echo Images to be updated:
dir /a:d /b
echo ------------------------------

echo Updating jellyfin
cd jellyfin
docker pull jellyfin/jellyfin
docker compose down
docker compose up -d
echo jellyfin updated successfully.
echo ------------------------------

echo Updating jackett
cd /d "..\jackett"
docker pull qmcgaw/gluetun
docker pull lscr.io/linuxserver/jackett
docker pull ghcr.io/flaresolverr/flaresolverr
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
docker pull qbittorrentofficial/qbittorrent-nox
docker compose down
docker compose up -d
echo qbittorrent updated successfully.
echo ------------------------------

echo Updating radarr
cd /d "..\radarr"
docker pull lscr.io/linuxserver/radarr
docker compose down
docker compose up -d
echo radarr updated successfully.
echo ------------------------------

echo Updating sonarr
cd /d "..\sonarr"
docker pull lscr.io/linuxserver/sonarr
docker compose down
docker compose up -d
echo sonarr updated successfully.
echo ------------------------------

echo Updating vsftpd
cd /d "..\vsftpd"
docker pull fauria/vsftpd
docker compose down
docker compose up -d
echo vsftpd updated successfully.
echo ------------------------------
docker image prune -f
pause
