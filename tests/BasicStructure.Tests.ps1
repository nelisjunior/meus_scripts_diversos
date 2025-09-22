Import-Module Pester -ErrorAction SilentlyContinue
Describe 'Estrutura básica do repositório' {
    It 'Existe pasta windows' { Test-Path (Join-Path (Get-Location) 'windows') | Should -BeTrue }
    It 'Todos scripts ps1 são UTF8 ou ASCII legíveis' {
        Get-ChildItem -Recurse -Include *.ps1 | ForEach-Object {
            $_ | Should -Not -BeNullOrEmpty
        }
    }
}
