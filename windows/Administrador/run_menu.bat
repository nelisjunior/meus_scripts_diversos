@echo off
REM Abre o ScriptsMenu.ps1 em uma nova janela do PowerShell (não elevado)
SET scriptPath=%~dp0ScriptsMenu.ps1
IF EXIST "%ProgramFiles%\PowerShell\7\pwsh.exe" (
    "%ProgramFiles%\PowerShell\7\pwsh.exe" -NoProfile -ExecutionPolicy Bypass -File "%scriptPath%"
) ELSE (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%scriptPath%"
)
