Import-Module Pester -ErrorAction SilentlyContinue
$testFilePath = $MyInvocation.MyCommand.Path
$testDir = Split-Path -Parent $testFilePath
$repoRoot = Split-Path -Parent $testDir
$scriptPath = Join-Path $repoRoot 'windows/noAdmin/Install-EdgeExtensions.ps1'

Describe 'InstallEdgeExtensions path debug' { It 'Resolve caminho InstallEdge' { Write-Host "repoRoot=$repoRoot"; Write-Host "scriptPath=$scriptPath"; Test-Path $scriptPath | Should -BeTrue } }

Describe 'Install-EdgeExtensions.ps1 - análise estática' {
    It 'Script existe' { Test-Path $scriptPath | Should -BeTrue }
}

Describe 'Install-EdgeExtensions.ps1 - simulação (mock IO)' {
    BeforeAll {
        function Stop-Process { param($Name) Write-Host "[MOCK] Stop-Process $Name" }
        function Remove-Item { param($Path,[switch]$Recurse,[switch]$Force) Write-Host "[MOCK] Remove $Path" }
        function Expand-Archive { param($Path,$DestinationPath,[switch]$Force) Write-Host "[MOCK] Expand $Path -> $DestinationPath" }
        $fakeRoot = Join-Path $env:TEMP 'EdgeExtFakeInstall'
        if (-not (Test-Path $fakeRoot)) { New-Item -ItemType Directory -Path $fakeRoot | Out-Null }
        $env:LOCALAPPDATA = $fakeRoot
        $backup = Join-Path (Get-Location) 'BackupEdgeExtensions'
        if (-not (Test-Path $backup)) { New-Item -ItemType Directory -Path $backup | Out-Null }
        # cria zips fake
    'a','b' | ForEach-Object { $zf = Join-Path $backup ($_.ToString() + '.zip'); if (-not (Test-Path $zf)) { New-Item -ItemType File -Path $zf | Out-Null } }
    }

    It 'Executa sem erro com mocks' {
        { pwsh -NoProfile -ExecutionPolicy Bypass -File $scriptPath } | Should -Not -Throw
    }
}
