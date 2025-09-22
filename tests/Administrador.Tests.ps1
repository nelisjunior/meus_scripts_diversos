Import-Module Pester -ErrorAction SilentlyContinue

# === Resolução simples e determinística ===
$script:thisFile = $MyInvocation.MyCommand.Path
$script:testsDir = Split-Path -Parent $thisFile
$script:repoRoot = Split-Path -Parent $testsDir

# Caminhos relativos (tests -> .. -> windows -> Administrador)
# Busca recursiva pelos scripts alvo após reorganização de pastas
function Find-FirstScript([string]$name){ Get-ChildItem -Path $repoRoot -Recurse -File -Filter $name -ErrorAction SilentlyContinue | Select-Object -First 1 }
$script:scriptsMenu = (Find-FirstScript 'ScriptsMenu.ps1')?.FullName
$script:wslCleanup  = (Find-FirstScript 'WSL_Cleanup.ps1')?.FullName

Write-Host "[DEBUG] repoRoot=$script:repoRoot" -ForegroundColor DarkGray
Write-Host "[DEBUG] testsDir=$script:testsDir" -ForegroundColor DarkGray
Write-Host "[DEBUG] scriptsMenu path=$script:scriptsMenu" -ForegroundColor DarkGray
Write-Host "[DEBUG] wslCleanup path=$script:wslCleanup" -ForegroundColor DarkGray

Describe 'Estrutura básica - scripts principais presentes' {
    It 'Repo possui pasta windows' { Test-Path (Join-Path $repoRoot 'windows') | Should -BeTrue }
    It 'ScriptsMenu encontrado' { Test-Path $scriptsMenu | Should -BeTrue }
    It 'WSL_Cleanup encontrado' { Test-Path $wslCleanup  | Should -BeTrue }
}

Describe 'ScriptsMenu.ps1 - funções' -Skip:(-not (Test-Path $scriptsMenu)) {
    BeforeAll {
        $env:SCRIPTSMENU_NO_LOOP = '1'
        . $scriptsMenu -NoLoop -DryRun
    }
    It 'Get-ScriptDescription presente' { Get-Command Get-ScriptDescription | Should -Not -BeNullOrEmpty }
    It 'Split-Args lida com espaços em aspas' {
        $t = Split-Args 'a "b c" d'
        $t.Count | Should -Be 3
        $t[1] | Should -Be 'b c'
    }
    It 'Format-DisplayArgs adiciona aspas quando necessário' { (Format-DisplayArgs @('aa','b c')) | Should -Match '"b c"' }
}

Describe 'WSL_Cleanup.ps1 - DryRun' -Skip:(-not (Test-Path $wslCleanup)) {
    It 'Executa em DryRun sem erro (bypass admin/wsl)' {
        $raw = Get-Content $wslCleanup -Raw
        $patched = $raw -replace '(?im)^Assert-Admin\s*$', '# bypass admin' -replace '(?s)if \(-not \(Get-Command wsl.*?exit 1\);?','# bypass wsl check'
        $tmp = New-TemporaryFile
        Set-Content -Path $tmp -Value $patched -Encoding UTF8
        { pwsh -NoProfile -ExecutionPolicy Bypass -File $tmp -DryRun -Force } | Should -Not -Throw
    }
}
