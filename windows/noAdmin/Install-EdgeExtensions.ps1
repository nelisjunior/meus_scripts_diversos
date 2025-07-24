[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Configuracões - BUSCA NA PASTA DO SCRIPT
$backupFolder = Join-Path -Path (Get-Location) -ChildPath "BackupEdgeExtensions"  # <-- Diretório atual
$edgeExtensionsPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Extensions"

# Fecha o Edge se estiver aberto
Stop-Process -Name "msedge" -ErrorAction SilentlyContinue

# Verifica se a pasta de backup existe
if (-not (Test-Path -Path $backupFolder)) {
    Write-Host "Pasta de backup nao encontrada!" -ForegroundColor Red
    Write-Host "Execute primeiro o script de backup." -ForegroundColor Yellow
    exit
}

# Processa cada arquivo ZIP
Get-ChildItem -Path $backupFolder -Filter *.zip | ForEach-Object {
    $id = $_.BaseName
    $extractPath = Join-Path -Path $edgeExtensionsPath -ChildPath $id

    try {
        # Remove versao existente
        if (Test-Path -Path $extractPath) {
            Remove-Item -Path $extractPath -Recurse -Force
        }

        # Extrai o ZIP
        Expand-Archive -Path $_.FullName -DestinationPath $edgeExtensionsPath -Force
        Write-Host "Extensao $id instalada" -ForegroundColor Green
    }
    catch {
        Write-Host "Falha ao instalar $id : $_" -ForegroundColor Red
    }
}

Write-Host "`nInstalacao concluida! Reinicie o Edge." -ForegroundColor Cyan