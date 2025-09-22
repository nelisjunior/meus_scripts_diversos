<#
.SYNOPSIS
    Menu interativo para listar e executar scripts PowerShell deste repositório.

.DESCRIPTION
    Este script procura todos os arquivos .ps1 no repositório (a partir da raiz do projeto),
    apresenta um menu com descrições extraídas dos cabeçalhos dos scripts e permite:
      - visualizar o conteúdo de um script
      - executar o script (no mesmo shell ou em novo processo)
      - executar com elevação (RunAs)
      - passar argumentos adicionais
      - usar modo dry-run para apenas exibir o comando que seria executado

.NOTES
    - Execute este menu em um PowerShell (padrão ou pwsh).
    - Para executar scripts que exigem privilégios, use a opção executar elevado.

#>

[CmdletBinding()]
param(
    [switch]$DryRun = $false,
    [switch]$NoLoop = $false  # permite testes automatizados pularem o menu interativo
)

# Configuração de log
$MenuLog = Join-Path $env:TEMP "ScriptsMenu_$(Get-Date -Format yyyyMMdd_HHmmss).log"
Add-Content -Path $MenuLog -Value "=== ScriptsMenu log started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" -ErrorAction SilentlyContinue

function Write-MenuLog([string]$level, [string]$msg) {
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$level] $msg"
    try { Add-Content -Path $MenuLog -Value $entry -ErrorAction SilentlyContinue } catch {}
    switch ($level) {
        'INFO'  { Write-Host $msg -ForegroundColor Cyan }
        'OK'    { Write-Host $msg -ForegroundColor Green }
        'WARN'  { Write-Host $msg -ForegroundColor Yellow }
        'ERROR' { Write-Host $msg -ForegroundColor Red }
        default { Write-Host $msg }
    }
}

function Write-Info { param($m) Write-MenuLog 'INFO' $m }
function Write-Good { param($m) Write-MenuLog 'OK' $m }
function Write-Warn { param($m) Write-MenuLog 'WARN' $m }
function Write-Err  { param($m) Write-MenuLog 'ERROR' $m }


# Determina raiz do repositório (duas pastas acima da pasta atual do script)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
try { $repoRoot = Resolve-Path (Join-Path $scriptDir '..\..') } catch { $repoRoot = Resolve-Path $scriptDir }

Write-Info "Scripts Menu - procurando .ps1 em: $repoRoot"

# Inicia transcript para debug completo
$MenuTranscript = Join-Path $env:TEMP "ScriptsMenu_transcript_$(Get-Date -Format yyyyMMdd_HHmmss).txt"
try { Start-Transcript -Path $MenuTranscript -ErrorAction SilentlyContinue } catch {}

function Get-ScriptDescription($path) {
    # Tenta extrair bloco de comentário <# ... #> ou primeiras linhas comentadas
    try {
        $lines = Get-Content -Path $path -ErrorAction Stop -TotalCount 50
    } catch { return '' }

    $inBlock = $false
    $descLines = @()
    foreach ($l in $lines) {
        if ($l -match '^\s*<#') { $inBlock = $true; continue }
        if ($l -match '#>') { break }
        if ($inBlock) { $descLines += ($l.Trim()) }
    }

    if ($descLines.Count -gt 0) {
        # busca .SYNOPSIS ou pega primeiras linhas não vazias
        $syn = $descLines | Where-Object { $_ -match '\.SYNOPSIS' } | Select-Object -First 1
        if ($syn) { return ($descLines -join ' ') -replace '\s+',' ' }
        return ($descLines | Where-Object { $_ -ne '' } | Select-Object -First 2) -join ' '
    }

    # fallback: procurar linhas de comentário no topo
    $topComments = $lines | Where-Object { $_ -match '^\s*#' } | ForEach-Object { ($_ -replace '^\s*#\s?','').Trim() }
    if ($topComments) { return ($topComments | Select-Object -First 2) -join ' ' }
    return ''
}

function Find-Scripts() {
    Get-ChildItem -Path $repoRoot -Recurse -Include *.ps1 -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -ne $MyInvocation.MyCommand.Path } |
        Sort-Object -Property FullName
}

function Build-CommandString($pwshPath, $filePath, $argsString) {
    $quotedPath = '"' + $filePath + '"'
    if ([string]::IsNullOrWhiteSpace($argsString)) { return "-NoProfile -ExecutionPolicy Bypass -File $quotedPath" }
    # Mantém os argumentos como string (usuário é responsável por citações corretas)
    return "-NoProfile -ExecutionPolicy Bypass -File $quotedPath $argsString"
}

# Split-Args: tokeniza uma string de argumentos respeitando aspas simples e duplas
function Split-Args([string]$argsString) {
    if ([string]::IsNullOrWhiteSpace($argsString)) { return @() }
    $pattern = @'
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
