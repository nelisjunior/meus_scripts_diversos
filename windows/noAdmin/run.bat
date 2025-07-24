@echo off
reg add "HKCU\Console" /v CodePage /t REG_DWORD /d 65001 /f
chcp 65001 > nul

:: Configuraçao de cores (removida para evitar conflitos com UTF-8)
:: Menu principal
:menu
cls
echo  [Menu Principal]
echo.
echo   1. Fazer backup de extensoes especificas do Edge
echo   2. Instalar extensoes a partir de arquivos ZIP
echo   3. Sair
echo.
set /p choice="Escolha uma opçao (1-3): "

if "%choice%"=="1" goto backup
if "%choice%"=="2" goto install
if "%choice%"=="3" exit /b

echo Opçao invalida! Pressione qualquer tecla para tentar novamente...
pause >nul
goto menu

:backup
cls
echo  [BACKUP DE EXTENSOES]
echo.
echo Verificando scripts disponiveis...

set "backup_script=%~dp0Backup-extensions.ps1"
if not exist "%backup_script%" (
    echo Erro: Script Backup-extensions.ps1 nao encontrado!
    pause
    goto menu
)

echo Executando backup das extensoes...
powershell -NoProfile -ExecutionPolicy Bypass -File "%backup_script%"
echo.
pause
goto menu

:install
cls
echo  [INSTALAÇaO DE EXTENSoES]
echo.
echo Verificando scripts disponiveis...

set "install_script=%~dp0Install-EdgeExtensions.ps1"
if not exist "%install_script%" (
    echo Erro: Script Install-EdgeExtensions.ps1 nao encontrado!
    pause
    goto menu
)

echo Executando instalaçao de extensoes...
powershell -NoProfile -ExecutionPolicy Bypass -File "%install_script%"
echo.
pause
goto menu