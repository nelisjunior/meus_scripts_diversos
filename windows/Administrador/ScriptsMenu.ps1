<#
.SYNOPSIS
    Menu interativo para listar e executar scripts PowerShell deste repositório.

.DESCRIPTION
    Este script procura todos os arquivos .ps1 no repositório (a partir da raiz do projeto),
    apresenta um menu com descrições extraídas dos cabeçalhos dos scripts e permite:
      - visualizar o conteúdo de um script
      - executar o script (no mesmo shell ou em novo processo)
    <#
    .SYNOPSIS
        Stub depreciado do antigo ScriptsMenu na pasta Administrador.

    .DESCRIPTION
        Esta versão foi simplificada para evitar redundância. Ela apenas encaminha o usuário
        para o launcher principal (WPF avançado) ou, se preferir modo console, para o
        `windows/menu/ScriptsMenu.ps1` real.

    .NOTES
        Você pode remover este arquivo futuramente após atualizar atalhos / automações.
    #>
    [CmdletBinding()]
    param(
        [switch]$Console,
        [switch]$DryRun
    )
    $menuDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\menu'
    $launcher = Join-Path $menuDir 'ScriptsLauncher.WPF.ps1'
    $console  = Join-Path $menuDir 'ScriptsMenu.ps1'
    Write-Host '[Aviso] Este ScriptsMenu legado foi depreciado.' -ForegroundColor Yellow
    if($Console){
        if(Test-Path $console){ Write-Host 'Abrindo versão de console...' -ForegroundColor Cyan; & $console -DryRun:$DryRun } else { Write-Warning "Console menu não encontrado em $console" }
    } else {
        if(Test-Path $launcher){ Write-Host 'Abrindo launcher WPF avançado...' -ForegroundColor Cyan; & $launcher -DryRun:$DryRun } elseif(Test-Path $console){ Write-Warning 'Launcher WPF não encontrado, caindo para console.'; & $console -DryRun:$DryRun } else { Write-Error 'Nenhuma versão de menu encontrada.' }
    }
("([^"\\]|\\.)*"|\'([^'\\]|\\.)*\'|\S+)
'@
    $matches = [regex]::Matches($argsString, $pattern)
    $list = @()
    foreach ($m in $matches) {
        $tok = $m.Value
        if (($tok.StartsWith('"') -and $tok.EndsWith('"')) -or ($tok.StartsWith("'") -and $tok.EndsWith("'"))) {
            $inner = $tok.Substring(1, $tok.Length - 2)
            $inner = $inner -replace '\\"','"' -replace "\\'","'" -replace '\\\\','\\'
            $list += $inner
        } else {
            $list += $tok
        }
    }
    return $list
}

function Format-DisplayArgs($argsArray) {
    $display = @()
    foreach ($a in $argsArray) { if ($a -match '\s') { $display += '"' + $a + '"' } else { $display += $a } }
    return $display -join ' '
}

# Encapsula o loop principal em função para permitir testes das funções auxiliares sem interatividade
function Start-ScriptsMenu {
    param(
        [switch]$DryRunFunction = $DryRun
    )
    # Mantém compatibilidade: variável original DryRun ainda usada internamente
    if ($DryRunFunction) { $script:DryRun = $true }

    while ($true) {
    $scripts = Find-Scripts
    if (-not $scripts) { Write-Warn "Nenhum script .ps1 encontrado em $repoRoot"; break }

    Write-Host "`n=== Scripts disponíveis ===" -ForegroundColor Cyan
    $i = 1
    $meta = @{}
    foreach ($s in $scripts) {
        $desc = Get-ScriptDescription $s.FullName
        $shortDesc = if ($desc) { if ($desc.Length -gt 80) { $desc.Substring(0,80) + '...' } else { $desc } } else { '' }
        Write-Host "[$i] $($s.FullName)" -ForegroundColor White
        if ($shortDesc) { Write-Host "     $shortDesc" -ForegroundColor DarkGray }
        $meta[$i] = $s.FullName
        $i++
    }

    Write-Host "`nEscolha um número para selecionar um script, múltiplos separados por vírgula (ex: 1,3-5) para executar em lote, 'r' para recarregar, 'q' para sair." -ForegroundColor Yellow
    $sel = Read-Host 'Número/ação'
    if ($sel -match '^[Rr]$') { continue }
    if ($sel -match '^[Qq]$') { break }
    # Suporte a seleção múltipla (ex: 1,3-5)
    $selectedIndexes = @()
    if ($sel -match ',|\-') {
        try {
            $parts = $sel -split ',' | ForEach-Object { $_.Trim() }
            foreach ($p in $parts) {
                if ($p -match '^(\d+)-(\d+)$') { $start = [int]$matches[1]; $end = [int]$matches[2]; $selectedIndexes += ($start..$end) }
                elseif ($p -match '^\d+$') { $selectedIndexes += [int]$p }
            }
        } catch { Write-Warn "Seleção inválida."; continue }
    } else {
        if (-not ($sel -as [int])) { Write-Warn "Entrada inválida."; continue }
        $selectedIndexes = ,([int]$sel)
    }

    # Validar índices
    $selectedIndexes = $selectedIndexes | Where-Object { $meta.ContainsKey($_) } | Sort-Object -Unique
    if (-not $selectedIndexes) { Write-Warn "Nenhum índice válido selecionado."; continue }

    if ($selectedIndexes.Count -eq 1) {
        $idx = $selectedIndexes[0]
        $scriptPath = $meta[$idx]
        Write-Info "Selecionado: $scriptPath"
        Write-Host "Opções: (v) visualizar | (e) executar | (u) executar elevado | (b) voltar" -ForegroundColor Yellow
        $action = Read-Host 'Ação'
    switch ($action.ToLower()) {
        'v' {
            Write-Host "`n--- Conteúdo: $scriptPath ---`n" -ForegroundColor Cyan
            Get-Content -Path $scriptPath -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ }
            Write-Host "--- Fim do arquivo ---`n" -ForegroundColor Cyan
            Read-Host 'Pressione Enter para continuar'
        }
        'e' {
            $argsString = Read-Host 'Argumentos (ex: -Force) - deixe vazio para nenhum'
            # escolhe pwsh se disponível, senão powershell
            $pwsh = if (Get-Command pwsh -ErrorAction SilentlyContinue) { (Get-Command pwsh).Source } else { (Get-Command powershell -ErrorAction SilentlyContinue).Source }
            if (-not $pwsh) { Write-Err "Nenhum executável PowerShell encontrado (pwsh ou powershell)."; continue }
            $argsArray = Split-Args $argsString
            $displayArgs = Format-DisplayArgs $argsArray
            $cmdDesc = "$pwsh -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" $displayArgs"
            Write-Host "Comando: $cmdDesc" -ForegroundColor DarkGray
            $confirm = Read-Host "Executar? (s/N)"
            if ($confirm -match '^[sSyY]$') {
                if ($DryRun) { Write-Warn "(dry-run) $cmdDesc"; Write-MenuLog 'INFO' "(dry-run) $cmdDesc"; continue }
                Write-Info "Executando..."
                Write-MenuLog 'INFO' "Executando comando: $cmdDesc"
                # Executa no mesmo processo (blocking) preservando argumentos
                $execArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$scriptPath) + $argsArray
                & $pwsh @execArgs
                Write-MenuLog 'INFO' "Comando finalizado"
            }
        }
        'u' {
            $argsString = Read-Host 'Argumentos (ex: -Force) - deixe vazio para nenhum'
            $pwsh = if (Get-Command pwsh -ErrorAction SilentlyContinue) { (Get-Command pwsh).Source } else { (Get-Command powershell -ErrorAction SilentlyContinue).Source }
            if (-not $pwsh) { Write-Err "Nenhum executável PowerShell encontrado (pwsh ou powershell)."; continue }
            $argsArray = Split-Args $argsString
            $displayArgs = Format-DisplayArgs $argsArray
            $cmdDesc = "$pwsh -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" $displayArgs"
            Write-Host "Comando elevado: $cmdDesc" -ForegroundColor DarkGray
            $confirm = Read-Host "Executar elevado? (s/N)"
            if ($confirm -match '^[sSyY]$') {
                if ($DryRun) { Write-Warn "(dry-run) Start-Process -Verb RunAs: $pwsh $cmdDesc"; Write-MenuLog 'INFO' "(dry-run) Start-Process -Verb RunAs: $pwsh $cmdDesc"; continue }
                try {
                    # Para Start-Process, passamos uma string única com argumentos, citando tokens com espaços
                    $argForStart = '-NoProfile -ExecutionPolicy Bypass -File "' + $scriptPath + '"'
                    if ($argsArray.Count -gt 0) { $argForStart += ' ' + $displayArgs }
                    Start-Process -FilePath $pwsh -ArgumentList $argForStart -Verb RunAs -WindowStyle Normal
                    Write-Good "Processo iniciado (elevado)."
                    Write-MenuLog 'INFO' "Processo iniciado (elevado): $pwsh $argForStart"
                } catch {
                    Write-Err "Falha ao iniciar elevado: $($_.Exception.Message)"
                    Write-MenuLog 'ERROR' "Falha ao iniciar elevado: $($_.Exception.Message)"
                }
            }
        }
        default { Write-Warn "Ação desconhecida." }
    }
    } else {
        # execução em lote para várias seleções
        Write-Info "Execução em lote para índices: $($selectedIndexes -join ',')"
        $confirmAll = Read-Host "Confirmar execução sequencial dos scripts selecionados? (s/N)"
        if ($confirmAll -notmatch '^[sSyY]$') { Write-Warn "Execução em lote cancelada."; continue }
        foreach ($idx in $selectedIndexes) {
            $scriptPath = $meta[$idx]
            Write-Info "-> Executando: $scriptPath"
            $pwsh = if (Get-Command pwsh -ErrorAction SilentlyContinue) { (Get-Command pwsh).Source } else { (Get-Command powershell -ErrorAction SilentlyContinue).Source }
            if (-not $pwsh) { Write-Err "Nenhum executável PowerShell encontrado (pwsh ou powershell)."; break }
            $argsString = Read-Host "Argumentos para $scriptPath (ou Enter para nenhum)"
            $argsArray = Split-Args $argsString
            $displayArgs = Format-DisplayArgs $argsArray
            $cmdDesc = "$pwsh -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" $displayArgs"
            Write-MenuLog 'INFO' "Executando (lote) comando: $cmdDesc"
            if ($DryRun) { Write-Warn "(dry-run) $cmdDesc"; continue }
            try {
                $execArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$scriptPath) + $argsArray
                & $pwsh @execArgs
                Write-Good "Concluído: $scriptPath"
                Write-MenuLog 'OK' "Concluído: $scriptPath"
            } catch {
                Write-Warn ("Erro ao executar {0}: {1}" -f $scriptPath, $_.Exception.Message)
                Write-MenuLog 'ERROR' ("Erro ao executar {0}: {1}" -f $scriptPath, $_.Exception.Message)
            }
        }
        Read-Host 'Pressione Enter para continuar'
    }
    }

    Write-Info "Saindo do menu." 
}

# Bloco try para capturar exceções não tratadas e salvar detalhes
try {
    if (-not $NoLoop -and -not $env:SCRIPTSMENU_NO_LOOP) {
        Start-ScriptsMenu
    } else {
        Write-Info "ScriptsMenu carregado em modo 'sem loop' (teste). Use Start-ScriptsMenu para iniciar manualmente."
    }
} catch {
    $errFile = Join-Path $env:TEMP 'ScriptsMenu_error.txt'
    $_ | Format-List * -Force | Out-File -FilePath $errFile -Encoding utf8 -Force
    Write-Err "Ocorreu um erro. Detalhes em: $errFile"
} finally {
    try { Stop-Transcript -ErrorAction SilentlyContinue } catch {}
}
