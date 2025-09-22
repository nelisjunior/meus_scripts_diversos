Import-Module Pester -ErrorAction SilentlyContinue
$testFilePath = $MyInvocation.MyCommand.Path
$testDir = Split-Path -Parent $testFilePath
$repoRoot = Split-Path -Parent $testDir
$scriptPath = Join-Path $repoRoot 'windows/noAdmin/Backup-extensions.ps1'

Describe 'BackupExtensions path debug' { It 'Resolve caminho Backup' { Write-Host "repoRoot=$repoRoot"; Write-Host "scriptPath=$scriptPath"; Test-Path $scriptPath | Should -BeTrue } }

Describe 'Backup-extensions.ps1 - análise estática' {
    It 'Script existe' { Test-Path $scriptPath | Should -BeTrue }
    It 'Define lista de extensões' { (Get-Content $scriptPath -Raw) | Should -Match 'extensionIDs' }
}

Describe 'Backup-extensions.ps1 - simulação (mock IO)' {
    BeforeAll {
        function Copy-Item { param($Path,$Destination,[switch]$Recurse,[switch]$Force) Write-Host "[MOCK] Copy $Path -> $Destination" }
        function Compress-Archive { param($Path,$DestinationPath,[switch]$Force) Write-Host "[MOCK] Zip $Path -> $DestinationPath" }
        function Remove-Item { param($Path,[switch]$Recurse,[switch]$Force) Write-Host "[MOCK] Remove $Path" }
        function explorer { param($p) Write-Host "[MOCK] explorer $p" }
        # Cria estrutura fake
        $fakeRoot = Join-Path $env:TEMP 'EdgeExtFake'
        if (-not (Test-Path $fakeRoot)) { New-Item -ItemType Directory -Path $fakeRoot | Out-Null }
        $env:LOCALAPPDATA = $fakeRoot
        $extensionsDir = Join-Path $fakeRoot 'Microsoft/Edge/User Data/Default/Extensions'
        New-Item -ItemType Directory -Path $extensionsDir -Force | Out-Null
        foreach ($id in 'a','b') { New-Item -ItemType Directory -Path (Join-Path $extensionsDir $id) -Force | Out-Null }
    }

    It 'Executa sem erro usando estrutura fake' {
        { pwsh -NoProfile -ExecutionPolicy Bypass -File $scriptPath } | Should -Not -Throw
    }
}
