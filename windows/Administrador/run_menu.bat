@echo off
REM Abre o novo launcher WPF avançado (não elevado)
SET scriptPath=%~dp0..\menu\ScriptsLauncher.WPF.ps1
IF EXIST "%ProgramFiles%\PowerShell\7\pwsh.exe" (
    "%ProgramFiles%\PowerShell\7\pwsh.exe" -NoProfile -ExecutionPolicy Bypass -File "%scriptPath%"
) ELSE (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%scriptPath%"
)
