@echo off
REM Lore launcher — called by Claude Desktop on every start.
REM Runs the update check in PowerShell (output suppressed), then invokes
REM the binary directly so MCP stdio communication is clean.
powershell -ExecutionPolicy Bypass -NoProfile -File "%USERPROFILE%\.lore\bin\update.ps1" >nul 2>&1
"%USERPROFILE%\.lore\bin\lore.exe" %*
