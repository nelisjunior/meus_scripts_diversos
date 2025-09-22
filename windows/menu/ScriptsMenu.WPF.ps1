<#
.SYNOPSIS
  Aplicativo WPF para explorar e executar scripts PowerShell do repositório.

.DESCRIPTION
  Interface visual moderna (XAML) com:
    - Lista de scripts (exclui testes por padrão)
    - Filtro incremental
    - Exibição de descrição + caminho
    - Visualização de conteúdo em janela separada
    - Execução normal ou elevada (multi-seleção)
    - Campo de argumentos (aplica a todos os selecionados)
    - Dry-Run
    - Log em tempo real
    - Alternar tema Claro/Escuro (simples)
    - Toggle para incluir scripts de teste

.NOTES
  Requisitos: Windows PowerShell 5+ OU PowerShell 7+ no Windows.
  Para empacotar em EXE: ver README (ex: ps2exe, ou Publish-PSResource + wrapper).

.PARAMETER StartPath
  Caminho base para procurar scripts (default: raiz deduzida).

.PARAMETER IncludeTests
  Inclui scripts de teste (*.Tests.ps1) e pasta tests se marcado no início.

.PARAMETER DryRun
  Apenas mostra comandos (não executa).

Autor: Automação Gerada
#>
<#
Stub depreciado: use ScriptsLauncher.WPF.ps1
#>
param()
$launcher = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'ScriptsLauncher.WPF.ps1'
Write-Host '[Aviso] ScriptsMenu.WPF.ps1 foi substituído. Iniciando ScriptsLauncher.WPF.ps1...' -ForegroundColor Yellow
if(Test-Path $launcher){ & $launcher } else { Write-Warning "Launcher não encontrado em $launcher" }

function Build-Command([string]$Pwsh,[string]$File,[string]$ArgsLine){
  $quoted = '"'+$File+'"'
  if([string]::IsNullOrWhiteSpace($ArgsLine)){ return "$Pwsh -NoProfile -ExecutionPolicy Bypass -File $quoted" }
  return "$Pwsh -NoProfile -ExecutionPolicy Bypass -File $quoted $ArgsLine"
}

$script:ShowTests = [bool]$IncludeTests
$script:ThemeDark = $false
$script:AllScripts = @()

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Scripts Menu (WPF)" Height="640" Width="1100" WindowStartupLocation="CenterScreen" MinWidth="900" MinHeight="500">
  <Grid Margin="8">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="180"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="*"/>
      <ColumnDefinition Width="380"/>
    </Grid.ColumnDefinitions>

    <!-- Top Bar -->
    <StackPanel Orientation="Horizontal" Grid.Row="0" Grid.ColumnSpan="2" Margin="0 0 0 6">
      <Label Content="Filtro:" VerticalAlignment="Center"/>
      <TextBox x:Name="TxtFilter" Width="220" Margin="4 0"/>
      <CheckBox x:Name="ChkDry" Content="Dry-Run" Margin="10 0"/>
      <CheckBox x:Name="ChkTests" Content="Incluir Testes" Margin="10 0"/>
      <Button x:Name="BtnReload" Content="Recarregar" Margin="12 0" Padding="10 2"/>
      <Button x:Name="BtnTheme" Content="Tema" Margin="4 0" Padding="10 2"/>
      <Button x:Name="BtnClose" Content="Fechar" Margin="12 0" Padding="10 2"/>
    </StackPanel>

    <!-- Scripts List -->
    <ListView x:Name="LvScripts" Grid.Row="1" Grid.Column="0" SelectionMode="Extended">
      <ListView.View>
        <GridView>
          <GridViewColumn Header="#" Width="40" DisplayMemberBinding="{Binding Index}" />
          <GridViewColumn Header="Nome" Width="220" DisplayMemberBinding="{Binding Name}" />
          <GridViewColumn Header="Descrição" Width="400" DisplayMemberBinding="{Binding ShortDescription}" />
        </GridView>
      </ListView.View>
    </ListView>

    <!-- Right Panel -->
    <DockPanel Grid.Row="1" Grid.Column="1" Margin="6 0 0 0">
      <TextBlock Text="Descrição / Caminho" FontWeight="Bold"/>
      <TextBox x:Name="TxtDesc" Margin="0 4 0 0" Height="140" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" IsReadOnly="True"/>
      <TextBlock Text="Argumentos (aplica a todos os selecionados):" Margin="0 8 0 0"/>
      <TextBox x:Name="TxtArgs" Margin="0 4 0 0"/>
      <StackPanel Orientation="Horizontal" Margin="0 8 0 0">
        <Button x:Name="BtnView" Content="Visualizar" Width="90" Margin="0 0 6 0"/>
        <Button x:Name="BtnRun" Content="Executar" Width="90" Margin="0 0 6 0"/>
        <Button x:Name="BtnElev" Content="Elevado" Width="90" Margin="0 0 6 0"/>
      </StackPanel>
    </DockPanel>

    <!-- Log -->
    <GroupBox Header="Log" Grid.Row="2" Grid.ColumnSpan="2" Margin="0 6 0 6">
      <TextBox x:Name="TxtLog" AcceptsReturn="True" VerticalScrollBarVisibility="Auto" IsReadOnly="True" TextWrapping="NoWrap" FontFamily="Consolas"/>
    </GroupBox>

    <!-- Status -->
    <StatusBar Grid.Row="3" Grid.ColumnSpan="2">
      <StatusBarItem>
        <TextBlock x:Name="LblStatus" Text="Pronto"/>
      </StatusBarItem>
      <StatusBarItem HorizontalAlignment="Right">
        <TextBlock x:Name="LblRoot" Text=""/>
      </StatusBarItem>
    </StatusBar>
  </Grid>
</Window>
'@

$reader = (New-Object System.Xml.XmlNodeReader ([xml]$xaml))
$Window = [Windows.Markup.XamlReader]::Load($reader)

# Controles
$TxtFilter = $Window.FindName('TxtFilter')
$ChkDry    = $Window.FindName('ChkDry')
$ChkTests  = $Window.FindName('ChkTests')
$BtnReload = $Window.FindName('BtnReload')
$BtnTheme  = $Window.FindName('BtnTheme')
$BtnClose  = $Window.FindName('BtnClose')
$LvScripts = $Window.FindName('LvScripts')
$TxtDesc   = $Window.FindName('TxtDesc')
$TxtArgs   = $Window.FindName('TxtArgs')
$BtnView   = $Window.FindName('BtnView')
$BtnRun    = $Window.FindName('BtnRun')
$BtnElev   = $Window.FindName('BtnElev')
$TxtLog    = $Window.FindName('TxtLog')
$LblStatus = $Window.FindName('LblStatus')
$LblRoot   = $Window.FindName('LblRoot')

$ChkDry.IsChecked   = [bool]$DryRun
$ChkTests.IsChecked = [bool]$IncludeTests
$LblRoot.Text       = $RepoRoot

function Add-Log([string]$Message){
  $entry = "$(Get-Date -Format 'HH:mm:ss') $Message"
  $TxtLog.AppendText($entry + [Environment]::NewLine)
  $TxtLog.ScrollToEnd()
}

function Shorten([string]$text,[int]$max=95){ if([string]::IsNullOrWhiteSpace($text)){ return '' }; if($text.Length -le $max){ return $text }; return $text.Substring(0,$max) + '…' }

function Refresh-Scripts {
  try {
    $LblStatus.Text = 'Carregando...'
    $script:AllScripts = Discover-Scripts
    Apply-Filter
    $LblStatus.Text = "${($script:AllScripts.Count)} scripts"
    Add-Log "Carregado $($script:AllScripts.Count) scripts."
  } catch {
    Add-Log "Erro: $($_.Exception.Message)"
    $LblStatus.Text = 'Erro'
  }
}

function Apply-Filter {
  $filter = $TxtFilter.Text.Trim()
  $data = if([string]::IsNullOrWhiteSpace($filter)){ $script:AllScripts } else { $script:AllScripts | Where-Object { $_.Name -like "*${filter}*" -or $_.FullName -like "*${filter}*" -or $_.Description -like "*${filter}*" } }
  $LvScripts.Items.Clear()
  $i=1
  foreach($s in $data){
    $LvScripts.Items.Add([PSCustomObject]@{ Index=$i; Name=$s.Name; ShortDescription=(Shorten $s.Description); Full=$s.FullName; Desc=$s.Description }) | Out-Null
    $i++
  }
}

function Show-SelectionInfo {
  if(-not $LvScripts.SelectedItems -or $LvScripts.SelectedItems.Count -eq 0){
    $TxtDesc.Text = 'Selecione um ou mais scripts.'; return
  }
  if($LvScripts.SelectedItems.Count -eq 1){
    $sel = $LvScripts.SelectedItems[0]
    $TxtDesc.Text = ($sel.Desc, '', $sel.Full) -join [Environment]::NewLine
  } else {
    $TxtDesc.Text = "${($LvScripts.SelectedItems.Count)} scripts selecionados."
  }
}

function View-Content {
  if($LvScripts.SelectedItems.Count -ne 1){ Add-Log 'Selecione exatamente UM script para visualizar.'; return }
  $file = $LvScripts.SelectedItems[0].Full
  $content = try { Get-Content -Path $file -ErrorAction Stop } catch { "Erro: $($_.Exception.Message)" }
  $viewer = New-Object System.Windows.Window
  $viewer.Title = "Visualizar - $file"
  $viewer.Width = 900; $viewer.Height = 600
  $tb = New-Object System.Windows.Controls.TextBox
  $tb.Text = ($content -join [Environment]::NewLine)
  $tb.IsReadOnly = $true; $tb.VerticalScrollBarVisibility='Auto'; $tb.HorizontalScrollBarVisibility='Auto'; $tb.FontFamily='Consolas'; $tb.AcceptsReturn=$true; $tb.AcceptsTab=$true; $tb.TextWrapping='NoWrap'
  $viewer.Content = $tb
  $viewer.ShowDialog() | Out-Null
}

function Execute-Selected([switch]$Elevated){
  if(-not $LvScripts.SelectedItems -or $LvScripts.SelectedItems.Count -eq 0){ Add-Log 'Nada selecionado.'; return }
  $pwsh = try { Get-PwshPath } catch { Add-Log $_; return }
  $argsLine = $TxtArgs.Text.Trim()
  foreach($item in $LvScripts.SelectedItems){
    $file = $item.Full
    $cmd = Build-Command -Pwsh $pwsh -File $file -ArgsLine $argsLine
    if($ChkDry.IsChecked){ Add-Log "(dry-run) $cmd"; continue }
    Add-Log "Executando: $cmd"
    try {
      if($Elevated){
        $argForStart = $cmd.Substring($pwsh.Length).Trim()
        Start-Process -FilePath $pwsh -ArgumentList $argForStart -Verb RunAs | Out-Null
        Add-Log 'Processo elevado iniciado.'
      } else {
        & $pwsh -NoProfile -ExecutionPolicy Bypass -File $file @($argsLine -split ' ')
        Add-Log "Concluído: $file"
      }
    } catch { Add-Log "Erro: $($_.Exception.Message)" }
  }
}

function Toggle-Theme {
  $script:ThemeDark = -not $script:ThemeDark
  if($script:ThemeDark){
    $Window.Background = 'Black'
    foreach($c in (Get-VisualChildren $Window)){ if($c -is [System.Windows.Controls.Control]){ $c.Foreground='White' } }
  } else {
    $Window.Background = 'White'
    foreach($c in (Get-VisualChildren $Window)){ if($c -is [System.Windows.Controls.Control]){ $c.Foreground='Black' } }
  }
}

function Get-VisualChildren([System.Windows.DependencyObject]$parent){
  $count = [System.Windows.Media.VisualTreeHelper]::GetChildrenCount($parent)
  for($i=0;$i -lt $count;$i++){
    $child = [System.Windows.Media.VisualTreeHelper]::GetChild($parent,$i)
    if($child){ $child; Get-VisualChildren $child }
  }
}

# EVENTOS
$TxtFilter.Add_TextChanged({ Apply-Filter })
$LvScripts.Add_SelectionChanged({ Show-SelectionInfo })
$BtnReload.Add_Click({ Refresh-Scripts })
$BtnView.Add_Click({ View-Content })
$BtnRun.Add_Click({ Execute-Selected })
$BtnElev.Add_Click({ Execute-Selected -Elevated })
$BtnTheme.Add_Click({ Toggle-Theme })
$BtnClose.Add_Click({ $Window.Close() })
$ChkTests.Add_Click({ $script:ShowTests = [bool]$ChkTests.IsChecked; Refresh-Scripts })

Add-Log "Raiz: $RepoRoot"
Refresh-Scripts
Show-SelectionInfo

[void]$Window.ShowDialog()
