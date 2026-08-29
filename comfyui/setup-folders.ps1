# Run this once to create the folder structure Docker Compose expects.
# Usage: powershell -ExecutionPolicy Bypass -File setup-folders.ps1
#
# Only the basedir (user files) is created here. ComfyUI's source code and its
# Python virtual environment live in the "comfyui-run" named Docker volume.

$base = $PSScriptRoot
$dirs = @(
    "basedir\models\checkpoints",
    "basedir\models\unet",
    "basedir\models\clip",
    "basedir\models\vae",
    "basedir\models\loras",
    "basedir\models\clip_vision",
    "basedir\output",
    "basedir\input",
    "basedir\custom_nodes",
    "basedir\user"
)

foreach ($d in $dirs) {
    $path = Join-Path $base $d
    New-Item -ItemType Directory -Force -Path $path | Out-Null
    Write-Host "Created: $path"
}

# The container runs as UID/GID 1000 and refuses to start if the mounts are
# owned by anyone else. New folders and volumes appear as root:root until chowned.
Write-Host "`nSetting ownership to 1000:1000 (requires Docker to be running)..."
docker volume create comfyui_comfyui-run | Out-Null
docker run --rm -v "comfyui_comfyui-run:/mnt" -v "$(Join-Path $base 'basedir'):/basedir" alpine chown -R 1000:1000 /mnt /basedir

Write-Host "`nDone. Now download the Flux models per README.md into basedir\models\unet, basedir\models\clip, basedir\models\vae."
