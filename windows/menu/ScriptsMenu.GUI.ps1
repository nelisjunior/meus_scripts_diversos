<#
.SYNOPSIS
    Interface gráfica para executar scripts PowerShell do repositório.

.DESCRIPTION
    Fornece uma janela com lista de scripts (exclui testes *.Tests.ps1), exibe descrição, permite:
      - Filtrar por texto
      - Visualizar conteúdo
      - Executar (normal ou elevado)
      - Executar múltiplos scripts em sequência
      - Modo Dry-Run
      - Passar argumentos (aplica a todos os selecionados)

.NOTES
    Requisitos: Windows PowerShell 5+ ou PowerShell 7+ em Windows.
    O modo elevado abre cada script em novo processo com Start-Process -Verb RunAs.
    Logs são exibidos em painel inferior.

.PARAMETER StartPath
    Caminho base para procurar scripts (default = raiz do repositório deduzida).

.PARAMETER IncludeTests
    Se definido, inclui scripts de teste (*.Tests.ps1) na listagem.

.PARAMETER DryRun
    Apenas mostra comandos que seriam executados.

#>
[CmdletBinding()]
param(
    [string]$StartPath,
    [switch]$IncludeTests,
    [switch]$DryRun
)

Add-Type -AssemblyName System.Windows.Forms | Out-Null
Add-Type -AssemblyName System.Drawing       | Out-Null

function Get-RepoRoot {
    param([string]$base)
    if ($base -and (Test-Path $base)) { return (Resolve-Path $base).Path }
    $here = Split-Path -Parent $MyInvocation.MyCommand.Path
    # subir duas pastas (menu -> windows -> raiz)
    $candidate = Resolve-Path (Join-Path $here '..\..') -ErrorAction SilentlyContinue
    if ($candidate) { return $candidate.Path }
    return (Get-Location).Path
}

$RepoRoot = Get-RepoRoot -base $StartPath

<#
Stub depreciado: use ScriptsLauncher.WPF.ps1
#>
param()
$launcher = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'ScriptsLauncher.WPF.ps1'
Write-Host '[Aviso] ScriptsMenu.GUI.ps1 depreciado. Abrindo ScriptsLauncher.WPF.ps1...' -ForegroundColor Yellow
if(Test-Path $launcher){ & $launcher } else { Write-Warning "Launcher não encontrado: $launcher" }
$lst = New-Object System.Windows.Forms.ListBox
$lst.Location = '10,70'
$lst.Size = New-Object System.Drawing.Size(600,480)
$lst.SelectionMode = 'MultiExtended'
$lst.HorizontalScrollbar = $true

$txtDesc = New-Object System.Windows.Forms.TextBox
$txtDesc.Location = '620,70'
$txtDesc.Multiline = $true
$txtDesc.Size = New-Object System.Drawing.Size(410,180)
$txtDesc.ReadOnly = $true
$txtDesc.ScrollBars = 'Vertical'

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = '620,260'
$txtLog.Multiline = $true
$txtLog.Size = New-Object System.Drawing.Size(410,290)
$txtLog.ReadOnly = $true
$txtLog.ScrollBars = 'Vertical'

foreach($c in @($lblFilter,$txtFilter,$chkDry,$btnReload,$btnView,$btnRun,$btnElev,$btnClose,$lblArgs,$txtArgs,$lst,$txtDesc,$txtLog)) { $form.Controls.Add($c) }

$global:_scriptsCache = @()

function Load-Scripts {
    try {
        $global:_scriptsCache = Discover-Scripts
        Apply-Filter
        Add-Log "Carregado $($global:_scriptsCache.Count) scripts."
    } catch { Add-Log "Erro ao descobrir scripts: $($_.Exception.Message)" }
}

function Apply-Filter {
    $lst.BeginUpdate()
    $lst.Items.Clear()
    $pattern = $txtFilter.Text.Trim()
    $filtered = if([string]::IsNullOrWhiteSpace($pattern)) { $global:_scriptsCache } else { $global:_scriptsCache | Where-Object { $_.Name -like "*${pattern}*" -or $_.FullName -like "*${pattern}*" } }
    foreach($s in $filtered){ [void]$lst.Items.Add($s.FullName) }
    $lst.EndUpdate()
}

function Add-Log([string]$msg) {
    $line = "$(Get-Date -Format 'HH:mm:ss') $msg"
    $txtLog.AppendText($line + [Environment]::NewLine)
}

function Current-Selection {
    if($lst.SelectedItems.Count -eq 0){ return @() }
    return @($lst.SelectedItems | ForEach-Object { $_ })
}

function Show-Description {
    $sel = Current-Selection
    if($sel.Count -eq 1){
        $file = $sel[0]
        $item = $global:_scriptsCache | Where-Object { $_.FullName -eq $file }
        $txtDesc.Text = ($item.Description, '', $file) -join [Environment]::NewLine
    } else {
        $txtDesc.Text = "Selecione um script (ou múltiplos para execução)."
    }
}

function View-Content {
    $sel = Current-Selection
    if($sel.Count -ne 1){ Add-Log 'Selecione exatamente um script para visualizar.'; return }
    $content = try { Get-Content -Path $sel[0] -ErrorAction Stop } catch { "Erro: $($_.Exception.Message)" }
    $viewer = New-Object System.Windows.Forms.Form
    $viewer.Text = "Visualizar - $($sel[0])"
    $viewer.Size = New-Object System.Drawing.Size(900,600)
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Multiline = $true; $tb.ReadOnly = $true; $tb.ScrollBars='Both'; $tb.WordWrap=$false
    $tb.Dock = 'Fill'
    $tb.Font = New-Object System.Drawing.Font('Consolas',9)
    $tb.Lines = $content
    $viewer.Controls.Add($tb)
    $viewer.ShowDialog() | Out-Null
}

function Execute-Scripts([switch]$Elevated){
    $sel = Current-Selection
    if($sel.Count -eq 0){ Add-Log 'Nenhum script selecionado.'; return }
    $pwsh = try { Get-PwshPath } catch { Add-Log $_; return }
    $argsLine = $txtArgs.Text.Trim()
    foreach($file in $sel){
        $cmd = Build-Command -pwsh $pwsh -file $file -argLine $argsLine
        if($chkDry.Checked){ Add-Log "(dry-run) $cmd"; continue }
        Add-Log "Executando: $cmd"
        try {
            if($Elevated){
                $argForStart = $cmd.Substring($pwsh.Length).Trim()
                Start-Process -FilePath $pwsh -ArgumentList $argForStart -Verb RunAs | Out-Null
            } else {
                # Execução inline (sincrona)
                & $pwsh -NoProfile -ExecutionPolicy Bypass -File $file @($argsLine -split ' ')
            }
            Add-Log (if($Elevated){ "Processo iniciado (elevado)" } else { "Concluído: $file" })
        } catch {
            Add-Log "Erro: $($_.Exception.Message)"
        }
    }
}

# Eventos
$txtFilter.add_TextChanged({ Apply-Filter })
$lst.add_SelectedIndexChanged({ Show-Description })
$btnReload.add_Click({ Load-Scripts })
$btnView.add_Click({ View-Content })
$btnRun.add_Click({ Execute-Scripts })
$btnElev.add_Click({ Execute-Scripts -Elevated })
$btnClose.add_Click({ $form.Close() })

Add-Log "Raiz: $RepoRoot"
Load-Scripts
Show-Description

[void]$form.ShowDialog()
