@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync-blender-game.ps1"
if errorlevel 1 (
    echo Update failed. Please keep the error output for diagnosis.
) else (
    echo Update complete. You can start the game now.
)
pause
