@echo off
setlocal

set "CONFIG_ROOT=%~dp0config"
set "KEEP=%CONFIG_ROOT%\qBittorrent\config\qBittorrent.conf"

if not exist "%CONFIG_ROOT%" (
    echo Config folder not found: %CONFIG_ROOT%
    pause
    exit /b 1
)

if exist "%KEEP%" (
    copy /y "%KEEP%" "%TEMP%\qBittorrent.conf.bak" >nul
    set "RESTORE=1"
) else (
    set "RESTORE=0"
)

echo Stopping container...
pushd "%~dp0"
docker compose down
if errorlevel 1 (
    echo Failed to stop the container. Aborting.
    popd
    pause
    exit /b 1
)
popd

for /d %%D in ("%CONFIG_ROOT%\*") do rd /s /q "%%D"
del /f /q "%CONFIG_ROOT%\*" >nul 2>&1

echo Cleared: %CONFIG_ROOT%

if "%RESTORE%"=="1" (
    mkdir "%CONFIG_ROOT%\qBittorrent\config" 2>nul
    move /y "%TEMP%\qBittorrent.conf.bak" "%KEEP%" >nul
    echo Preserved: %KEEP%
) else (
    echo Not found, nothing preserved: %KEEP%
)

echo Starting container...
pushd "%~dp0"
docker compose up -d
popd

echo.
echo Done.
pause
endlocal
