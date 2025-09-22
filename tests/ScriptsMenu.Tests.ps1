Import-Module Pester -ErrorAction SilentlyContinue
$repoRoot = $env:REPO_ROOT
if (-not $repoRoot -or -not (Test-Path $repoRoot)) { $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
$scriptPath = Join-Path $repoRoot 'windows/Administrador/ScriptsMenu.ps1'

Describe 'ScriptsMenu.ps1 - funções utilitárias' {
    BeforeAll {
        if (Test-Path $scriptPath) {
            $env:SCRIPTSMENU_NO_LOOP = '1'
            . $scriptPath -NoLoop -DryRun
        }
    }

    It 'Define funções esperadas' -Skip:(-not (Test-Path $scriptPath)) {
        (Get-Command Get-ScriptDescription) | Should -Not -BeNullOrEmpty
        (Get-Command Split-Args) | Should -Not -BeNullOrEmpty
        (Get-Command Format-DisplayArgs) | Should -Not -BeNullOrEmpty
    }

    It 'Split-Args divide corretamente argumentos com e sem aspas' -Skip:(-not (Get-Command Split-Args -ErrorAction SilentlyContinue)) {
        $result = Split-Args 'one "two words" three'
        $result.Count | Should -Be 3
        $result[1] | Should -Be 'two words'
    }

    It 'Format-DisplayArgs adiciona aspas em argumentos com espaço' -Skip:(-not (Get-Command Format-DisplayArgs -ErrorAction SilentlyContinue)) {
        $r = Format-DisplayArgs @('abc','dois termos','x')
        $r | Should -Match '"dois termos"'
    }
}
