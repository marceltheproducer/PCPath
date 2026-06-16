@echo off
REM Double-click entry point: bump minor, build, sync all 4 locations,
REM commit + push, then launch the rebuilt installer.
REM
REM Pass extra args through, e.g.  sync.cmd -NoBump  /  sync.cmd -BumpMajor
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync.ps1" -Install %*
pause
