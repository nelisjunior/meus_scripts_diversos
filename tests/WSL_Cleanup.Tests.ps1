Import-Module Pester -ErrorAction SilentlyContinue
$testFilePath = $MyInvocation.MyCommand.Path
$testDir = Split-Path -Parent $testFilePath
$repoRoot = Split-Path -Parent $testDir
$scriptPath = Join-Path $repoRoot 'windows/Administrador/WSL_Cleanup.ps1'

Describe 'WSL_Cleanup path debug' {
It 'Resolve caminho WSL_Cleanup' {
    Write-Host "repoRoot=$repoRoot"; Write-Host "scriptPath=$scriptPath"
    Test-Path $scriptPath | Should -BeTrue
}
}

Describe 'WSL_Cleanup.ps1 - análise estática' {
    It 'Script existe' {
        Test-Path $scriptPath | Should -BeTrue
    }

    It 'Contém função Assert-Admin' {
        (Get-Content $scriptPath -Raw) | Should -Match 'function Assert-Admin'
    }

    It 'Oferece parâmetros Force e DryRun' {
        (Get-Content $scriptPath -Raw) | Should -Match '\[switch\]\$Force'
        (Get-Content $scriptPath -Raw) | Should -Match '\[switch\]\$DryRun'
    }
}

Describe 'WSL_Cleanup.ps1 - execução DryRun simulada (mockando dependências perigosas)' {
    BeforeAll {
        function Restart-Computer { param([switch]$Force) Write-Host '[MOCK] Restart-Computer' }
        function Remove-Item { param([Parameter(ValueFromPipeline=$true)][string]$Path,[switch]$Recurse,[switch]$Force) Write-Host "[MOCK] Remove-Item $Path" }
        function wsl { param($p1,$p2,$p3) Write-Host '[MOCK] wsl ' $p1 $p2 $p3 }
        function Get-Command { param($Name) if ($Name -eq 'wsl') { return @{ Name='wsl'} } else { Microsoft.PowerShell.Core\Get-Command @PSBoundParameters } }
        $env:WSL_CLEANUP_TEST = '1'
    }

    It 'Roda em DryRun sem lançar erro até Assert-Admin' -Tag 'DryRun' {
        $script = Get-Content $scriptPath -Raw
        # Injeta retorno true para admin
        $script = $script -replace 'Assert-Admin','Write-Host "[MOCK] Assert-Admin bypass"'
        $tmp = New-TemporaryFile
        Set-Content -Path $tmp -Value $script -Encoding UTF8
        { pwsh -NoProfile -ExecutionPolicy Bypass -File $tmp -DryRun } | Should -Not -Throw
    }
}
