@echo off
REM Lança o menu de scripts em modo elevado
SET scriptPath=%~dp0ScriptsMenu.ps1
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" (
    powershell -Command "Start-Process -FilePath '%ProgramFiles%\PowerShell\7\pwsh.exe' -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%scriptPath%\"' -Verb RunAs"
) else (
    powershell -Command "Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%scriptPath%\"' -Verb RunAs"
)