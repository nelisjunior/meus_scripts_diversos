// Movido de windows/noAdmin/Install-EdgeExtensions.ps1
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$backupFolder = Join-Path -Path (Get-Location) -ChildPath "BackupEdgeExtensions"
$edgeExtensionsPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Extensions"
Stop-Process -Name "msedge" -ErrorAction SilentlyContinue
if (-not (Test-Path -Path $backupFolder)) { Write-Host "Pasta de backup nao encontrada!" -ForegroundColor Red; Write-Host "Execute primeiro o script de backup." -ForegroundColor Yellow; exit }
Get-ChildItem -Path $backupFolder -Filter *.zip | ForEach-Object { $id = $_.BaseName; $extractPath = Join-Path -Path $edgeExtensionsPath -ChildPath $id; try { if (Test-Path -Path $extractPath) { Remove-Item -Path $extractPath -Recurse -Force }; Expand-Archive -Path $_.FullName -DestinationPath $edgeExtensionsPath -Force; Write-Host "Extensao $id instalada" -ForegroundColor Green } catch { Write-Host "Falha ao instalar $id : $_" -ForegroundColor Red } }
Write-Host "`nInstalacao concluida! Reinicie o Edge." -ForegroundColor Cyan