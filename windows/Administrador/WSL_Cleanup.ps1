<#
.SYNOPSIS
    Script de limpeza do WSL (resolve situações como ERROR_FILE_NOT_FOUND e residuais de distribuições)

.DESCRIPTION
    Este script para serviços WSL, desregistra distribuições selecionadas, remove pastas residuais
    de pacotes (Windows Store) relacionadas ao Ubuntu/WSL e apaga arquivos VHDX residuais.

.NOTES
    - Execute como Administrador.
    - Tem suporte a -Force (responde sim para todas as confirmações) e -DryRun (apenas mostra o que faria).
    - Foi escrito para Windows PowerShell / PowerShell 7+.

.PARAMETER Force
    Ignora confirmações interativas.

.PARAMETER DryRun
    Não executa remoções; apenas mostra as ações que seriam tomadas.

.PARAMETER Distros
    Lista de nomes de distribuições para tentar remover. Se não informado, detecta instaladas.

#>

[CmdletBinding()]
param(
    [switch]$Force = $false,
    [switch]$DryRun = $false,
    [string[]]$Distros
)

# Configuração de log (arquivo)
$LogFile = Join-Path $env:TEMP "WSL_Cleanup_$(Get-Date -Format yyyyMMdd_HHmmss).log"
Add-Content -Path $LogFile -Value "=== WSL_Cleanup log started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" -ErrorAction SilentlyContinue

function Write-Log([string]$level, [string]$msg) {
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$level] $msg"
    try { Add-Content -Path $LogFile -Value $entry -ErrorAction SilentlyContinue } catch {}
    switch ($level) {
        'INFO'  { Write-Host $msg -ForegroundColor Cyan }
        'OK'    { Write-Host $msg -ForegroundColor Green }
        'WARN'  { Write-Host $msg -ForegroundColor Yellow }
        'ERROR' { Write-Host $msg -ForegroundColor Red }
        default { Write-Host $msg }
    }
}

function Write-Info { param($msg) Write-Log 'INFO' $msg }
function Write-Good { param($msg) Write-Log 'OK' $msg }
function Write-Warn { param($msg) Write-Log 'WARN' $msg }
function Write-Err  { param($msg) Write-Log 'ERROR' $msg }

# Verifica se está como Administrador
function Assert-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Err "ERRO: Este script deve ser executado como Administrador!"
        Write-Warn "Abra o PowerShell como Administrador e rode novamente."
        exit 1
    }
}

function Confirm-Or-Default([string]$message) {
    if ($Force) { return $true }
    if ($DryRun) { Write-Warn "(dry-run) Pergunta: $message"; return $false }
    $resp = Read-Host "$message (s/N)"
    return ($resp -match '^[sSyY]$')
}

function Run-Command([string]$cmd) {
    if ($DryRun) { Write-Warn "(dry-run) Comando: $cmd"; return $true }
    Write-Log 'INFO' "Executando comando: $cmd"
    & cmd /c "$cmd"
    $ok = $LASTEXITCODE -eq 0
    if ($ok) { Write-Log 'OK' "Comando finalizado com código 0" } else { Write-Log 'WARN' "Comando finalizado com código $LASTEXITCODE" }
    return $ok
}

Write-Info "=== LIMPEZA DO WSL - RESOLUÇÃO ERROR_FILE_NOT_FOUND ==="
Write-Info "Iniciando processo de limpeza..."
Write-Log 'INFO' "Parâmetros: Force=$Force DryRun=$DryRun Distros=$($Distros -join ',')"

Assert-Admin

# Verifica existência do binário wsl
if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
    Write-Err "Comando 'wsl' não encontrado. Verifique se o WSL está instalado.";
    exit 1
}

# 1) Parar serviços WSL
Write-Info "`n[1/5] Parando serviços WSL..."
try {
    if ($DryRun) { Write-Warn "(dry-run) wsl --shutdown" }
    else { wsl --shutdown }
    Start-Sleep -Seconds 2
    Write-Good "✓ Serviços WSL parados (ou não havia serviços em execução)."
} catch {
    Write-Warn "⚠ Falha ao parar serviços WSL (pode ser normal se não havia nada rodando)."
    Write-Log 'WARN' "Erro ao parar services WSL: $($_.Exception.Message)"
}

# 2) Detectar distribuições instaladas (se Distros não informado)
Write-Info "`n[2/5] Detectando distribuições WSL instaladas..."
$installed = @()
try {
    $lines = wsl --list --quiet 2>$null
    if ($lines) { $installed = $lines | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' } }
} catch {
    Write-Warn "Não foi possível listar distribuições via 'wsl --list --quiet'. Continuando com lista padrão."
    Write-Log 'WARN' "Erro ao listar distribuições: $($_.Exception.Message)"
}

if ($Distros -and $Distros.Length -gt 0) {
    $candidates = $Distros
} elseif ($installed.Length -gt 0) {
    $candidates = $installed
} else {
    # lista padrão (compatível com seu código original)
    $candidates = @('Ubuntu','Ubuntu-24.04','Ubuntu-22.04','Ubuntu-20.04','Ubuntu-18.04')
}

Write-Info "Distribuições candidatas: $($candidates -join ', ')"
Write-Log 'INFO' "Distribuições candidatas: $($candidates -join ', ')"

$removedCount = 0
Write-Info "`n[3/5] Desregistrando distribuições selecionadas..."
foreach ($d in $candidates) {
    if ($installed -and ($installed -contains $d)) {
        $doRemove = $Force -or Confirm-Or-Default "Deseja remover a distribuição '$d'?"
        if ($doRemove) {
        if ($DryRun) { Write-Warn "(dry-run) wsl --unregister $d"; Write-Log 'INFO' "(dry-run) wsl --unregister $d"; $removedCount++ ; continue }
            Write-Info "Removendo $d..."
            wsl --unregister "$d" 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Good "✓ $d removida com sucesso"
                Write-Log 'OK' "$d removida com sucesso"
                $removedCount++
            } else {
                Write-Warn "⚠ Não foi possível remover $d (código: $LASTEXITCODE)."
                Write-Log 'WARN' "Não foi possível remover $d (código: $LASTEXITCODE)."
            }
        }
    } else {
    Write-Info "Ignorando $d (não encontrado entre instaladas)."
    Write-Log 'INFO' "Ignorando $d (não instalado)"
    }
}

# 4) Limpeza de pastas residuais em LocalAppData\Packages
Write-Info "`n[4/5] Limpando pastas residuais em '%LOCALAPPDATA%\\Packages' e arquivos VHDX..."
$packagesPath = Join-Path $env:LOCALAPPDATA 'Packages'
$patterns = @('CanonicalGroupLimited.Ubuntu*','CanonicalGroupLimited.UbuntuonWindows*')

$cleanedCount = 0
foreach ($pat in $patterns) {
    try {
        $folders = Get-ChildItem -Path $packagesPath -Directory -Filter $pat -ErrorAction SilentlyContinue
        foreach ($f in $folders) {
            Write-Info "Processando: $($f.FullName)"
            Write-Log 'INFO' "Processando pasta: $($f.FullName)"
            # procurar arquivos VHDX dentro da pasta (ex: LocalState\ext4.vhdx)
            $vhdx = Get-ChildItem -Path $f.FullName -Recurse -Include *.vhdx -ErrorAction SilentlyContinue
            if ($vhdx) {
                foreach ($v in $vhdx) {
                    $doDelVhd = $Force -or Confirm-Or-Default "Excluir VHDX '$($v.FullName)'?"
                    if ($doDelVhd) {
                        if ($DryRun) { Write-Warn "(dry-run) Remover VHDX: $($v.FullName)"; Write-Log 'INFO' "(dry-run) Remover VHDX: $($v.FullName)"; continue }
                        try { Remove-Item -Path $v.FullName -Force -ErrorAction Stop; Write-Good "✓ VHDX removido: $($v.FullName)"; Write-Log 'OK' "VHDX removido: $($v.FullName)" } catch { Write-Warn "Erro ao remover VHDX: $($_.Exception.Message)"; Write-Log 'WARN' "Erro ao remover VHDX: $($_.Exception.Message)" }
                    }
                }
            }

            $doDel = $Force -or Confirm-Or-Default "Excluir pasta de pacote '$($f.Name)' (conteúdo Windows Store / LocalState)?"
            if ($doDel) {
                if ($DryRun) { Write-Warn "(dry-run) Remover pasta: $($f.FullName)"; Write-Log 'INFO' "(dry-run) Remover pasta: $($f.FullName)"; $cleanedCount++; continue }
                try {
                    Remove-Item -Path $f.FullName -Recurse -Force -ErrorAction Stop
                    if (-not (Test-Path $f.FullName)) { Write-Good "✓ Pasta $($f.Name) excluída"; Write-Log 'OK' "Pasta excluída: $($f.FullName)"; $cleanedCount++ }
                    else { Write-Warn "⚠ Não foi possível excluir $($f.Name)"; Write-Log 'WARN' "Não foi possível excluir: $($f.FullName)" }
                } catch {
                    Write-Warn "Erro ao excluir $($f.FullName): $($_.Exception.Message)"
                    Write-Log 'WARN' "Erro ao excluir $($f.FullName): $($_.Exception.Message)"
                }
            }
        }
    } catch {
        Write-Warn "Erro ao processar padrão $pat: $($_.Exception.Message)"
        Write-Log 'WARN' "Erro ao processar padrão $pat: $($_.Exception.Message)"
    }
}

# 5) Limpar cache temporário do WSL
Write-Info "`n[5/5] Limpando cache temporário do WSL..."
$wslCachePath = Join-Path $env:TEMP 'WSL'
if (Test-Path $wslCachePath) {
    if ($Force -or Confirm-Or-Default "Excluir cache em '$wslCachePath'?") {
        if ($DryRun) { Write-Warn "(dry-run) Remover: $wslCachePath"; Write-Log 'INFO' "(dry-run) Remover cache: $wslCachePath" }
        else {
            try { Remove-Item -Path "$wslCachePath\*" -Recurse -Force -ErrorAction SilentlyContinue; Write-Good "✓ Cache do WSL limpo"; Write-Log 'OK' "Cache do WSL limpo: $wslCachePath" } catch { Write-Warn "Não foi possível limpar o cache: $($_.Exception.Message)"; Write-Log 'WARN' "Não foi possível limpar o cache: $($_.Exception.Message)" }
        }
    }
} else {
    Write-Info "Cache do WSL não encontrado em: $wslCachePath"
}

# Resumo
Write-Info "`n=== RESUMO DA LIMPEZA ==="
Write-Host "Distribuições removidas: $removedCount" -ForegroundColor White
Write-Host "Pastas/pacotes limpos: $cleanedCount" -ForegroundColor White
Write-Log 'INFO' "Resumo: Distribuições removidas=$removedCount Pastas limpas=$cleanedCount"
Write-Info "`nPróximos passos recomendados:"
Write-Host "1. Reinicie o computador (recomendado)" -ForegroundColor White
Write-Host "2. Reinstale uma distribuição se desejar: wsl --install -d Ubuntu" -ForegroundColor White

if (-not $Force) {
    $restart = Read-Host "`nDeseja reiniciar o computador agora? (s/N)"
    if ($restart -match '^[sSyY]$') {
        Write-Warn "Reiniciando em 5 segundos..."
        Write-Log 'INFO' "Usuário optou por reiniciar o computador"
        Start-Sleep -Seconds 5
        if ($DryRun) { Write-Warn "(dry-run) Restart-Computer -Force" } else { Restart-Computer -Force }
    }
}

Write-Good "`nLimpeza concluída! 🧹"
