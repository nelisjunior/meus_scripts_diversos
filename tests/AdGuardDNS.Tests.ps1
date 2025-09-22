Import-Module Pester -ErrorAction SilentlyContinue
$testFilePath = $MyInvocation.MyCommand.Path
$testDir = Split-Path -Parent $testFilePath
$repoRoot = Split-Path -Parent $testDir
$scriptPath = Join-Path $repoRoot 'windows/rede/AdGuardDNS.ps1'

Describe 'AdGuardDNS path debug' { It 'Resolve caminho AdGuard' { Write-Host "repoRoot=$repoRoot"; Write-Host "scriptPath=$scriptPath"; Test-Path $scriptPath | Should -BeTrue } }

Describe 'AdGuardDNS.ps1 - análise' {
    It 'Script existe' { Test-Path $scriptPath | Should -BeTrue }
    It 'Contém IP primário 94.140.14.14' { (Get-Content $scriptPath -Raw) | Should -Match '94.140.14.14' }
}

Describe 'AdGuardDNS.ps1 - fluxo interativo simplificado' {
    BeforeAll {
        function netsh { param($args) Write-Host "[MOCK] netsh $args" }
        function Start-Process { param($FilePath,$ArgumentList,[switch]$Verb) Write-Host "[MOCK] Start-Process $FilePath $ArgumentList" }
        function Read-Host { param($msg) if ($msg -match 'Escolha a opção') { return 2 } elseif ($msg -match 'Deseja continuar') { return 's' } elseif ($msg -match 'Deseja verificar') { return 'n' } else { return 'n' } }
        # Força contexto admin simulando verificação
        $content = Get-Content $scriptPath -Raw
    $content = $content -replace '(?s)if \(-not \(\[Security.Principal.WindowsPrincipal\].+?exit','# bypass admin check'
        $tmp = New-TemporaryFile
        Set-Content -Path $tmp -Value $content -Encoding UTF8
        Set-Variable -Name 'AdGuardTempScript' -Value $tmp -Scope Global
    }
    It 'Executa caminho restauração DNS (opção 2) sem erro' {
        { pwsh -NoProfile -ExecutionPolicy Bypass -File $AdGuardTempScript } | Should -Not -Throw
    }
}
