@echo off
REM Lança o menu de scripts (não elevado)
SET scriptPath=%~dp0ScriptsMenu.ps1
IF EXIST "%ProgramFiles%\PowerShell\7\pwsh.exe" (
    "%ProgramFiles%\PowerShell\7\pwsh.exe" -NoProfile -ExecutionPolicy Bypass -File "%scriptPath%"
) ELSE (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%scriptPath%"
)