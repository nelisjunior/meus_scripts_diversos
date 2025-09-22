// Movido de windows/noAdmin/Backup-extensions.ps1
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$edgeExtensionsPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Extensions"
$backupFolderName = "BackupEdgeExtensions"
$backupFolder = Join-Path -Path (Get-Location) -ChildPath $backupFolderName
$extensionIDs = @(
    "dppgmdbiimibapkepcbdbmkaabgiofem",
    "odfafepnkmbhccpbejgmiehpchacaeak",
    "hfjadhjooeceemgojogkhlppanjkbobc"
)
if (-not (Test-Path -Path $edgeExtensionsPath)) { Write-Host "Pasta de extensoes do Edge nao encontrada!" -ForegroundColor Red; exit }
if (-not (Test-Path -Path $backupFolder)) { New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null }
foreach ($id in $extensionIDs) { $sourcePath = Join-Path -Path $edgeExtensionsPath -ChildPath $id; $destPath = Join-Path -Path $backupFolder -ChildPath $id; $zipPath = Join-Path -Path $backupFolder -ChildPath "$id.zip"; if (Test-Path -Path $sourcePath) { try { Copy-Item -Path $sourcePath -Destination $destPath -Recurse -Force; Compress-Archive -Path $destPath -DestinationPath $zipPath -Force; Remove-Item -Path $destPath -Recurse -Force; Write-Host "$id -> $(Split-Path $zipPath -Leaf)" -ForegroundColor Green } catch { Write-Host "Falha ao processar $id : $_" -ForegroundColor Red } } else { Write-Host "Extensao $id nao encontrada" -ForegroundColor Yellow } }
Write-Host "`nBackup concluido! Pasta: $backupFolder" -ForegroundColor Cyan
explorer $backupFolder