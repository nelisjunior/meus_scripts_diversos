<#
.SYNOPSIS
  Launcher WPF avançado para scripts PowerShell do repositório.

.DESCRIPTION
  Recursos principais:
    - Árvore de categorias (pastas) com contagem
    - Lista detalhada de scripts filtrados
    - Favoritos persistentes em JSON (AppData)
    - Exibição de cabeçalho (comment-based help) e primeiros comentários inline
    - Busca incremental (nome, caminho, descrição)
    - Execução normal / elevada / dry-run
    - Argumentos específicos por script (persistidos)
    - Histórico recente (últimos 15 executados)
    - Inclusão opcional de testes
    - Botão para abrir arquivo no editor padrão
    - Tema claro/escuro

.NOTES
  Armazena preferências em: $env:APPDATA\ScriptsLauncher\settings.json
  Necessário Windows (WPF). Testado PowerShell 7.
#>
[CmdletBinding()]
param(
  [string]$Root,
  [switch]$IncludeTests,
  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

Add-Type -AssemblyName PresentationCore,PresentationFramework,WindowsBase | Out-Null

# ---------------- Persistência ----------------
$AppDir = Join-Path $env:APPDATA 'ScriptsLauncher'
if(-not (Test-Path $AppDir)){ New-Item -ItemType Directory -Path $AppDir | Out-Null }
$SettingsFile = Join-Path $AppDir 'settings.json'
$script:State = [ordered]@{
  Favorites = @()
  PerScriptArgs = @{}
  Recent = @()
  DarkTheme = $false
}
if(Test-Path $SettingsFile){
  try { $loaded = Get-Content $SettingsFile -Raw | ConvertFrom-Json -ErrorAction Stop
    foreach($k in $script:State.Keys){ if($loaded.PSObject.Properties.Name -contains $k){ $script:State[$k] = $loaded.$k } }
  } catch { Write-Verbose "Falha ao carregar settings: $($_.Exception.Message)" }
}
function Save-State { $script:State | ConvertTo-Json -Depth 6 | Set-Content -Path $SettingsFile -Encoding UTF8 }

# ---------------- Utilidades ----------------
function Get-Root {
  try {
    if($Root -and (Test-Path -LiteralPath $Root)){
      $rp = Resolve-Path -LiteralPath $Root -ErrorAction Stop | Select-Object -First 1
      if($rp -is [string]){ return (Resolve-Path -LiteralPath $rp).Path }
      if($rp.PSObject.Properties['Path']){ return $rp.Path }
    }
  } catch {}
  try {
    $here = Split-Path -Parent $MyInvocation.MyCommand.Path
    $candidate = Join-Path $here '..\\..'
    if(Test-Path -LiteralPath $candidate){
      $rp2 = Resolve-Path -LiteralPath $candidate -ErrorAction SilentlyContinue | Select-Object -First 1
      if($rp2){
        if($rp2 -is [string]){ return (Resolve-Path -LiteralPath $rp2).Path }
        if($rp2.PSObject.Properties['Path']){ return $rp2.Path }
      }
    }
  } catch {}
  return (Get-Location).Path
}
$RepoRoot = Get-Root

function Read-Description([string]$File){
  try { $lines = Get-Content -Path $File -TotalCount 120 } catch { return '' }
  $block=@();$capture=$false
  foreach($l in $lines){
    if($l -match '^\s*<#'){ $capture=$true; continue }
    if($capture){ if($l -match '#>'){ break }; $block+=$l }
  }
  if($block.Count){
    $syn = $block | Where-Object { $_ -match '\.SYNOPSIS' } | Select-Object -First 1
    $txt = (($block -join ' ') -replace '\s+',' ').Trim()
    if($syn){ return $txt }
    return $txt
  }
  return ''
}

function Discover-AllScripts {
  $all = Get-ChildItem -Path $RepoRoot -Recurse -File -Filter *.ps1 -ErrorAction SilentlyContinue
  if(-not $script:ShowTests){ $all = $all | Where-Object { $_.Name -notmatch '\.Tests\.ps1$' -and $_.FullName -notmatch "\\tests\\" } }
  $all | ForEach-Object {
    $rel = $_.FullName.Substring($RepoRoot.Length)
    while($rel.StartsWith('\\') -or $rel.StartsWith('/')){ $rel = $rel.Substring(1) }
    $folderPath = Split-Path $rel -Parent
    [PSCustomObject]@{
      Name = $_.Name
      Relative = $rel
      Full = $_.FullName
      Folder = $folderPath
      Description = Read-Description -File $_.FullName
    }
  }
}

function Get-Pwsh { foreach($c in 'pwsh','powershell'){ $cmd=Get-Command $c -ErrorAction SilentlyContinue; if($cmd){ return $cmd.Source } }; throw 'PowerShell runtime não encontrado.' }

function Short([string]$t,[int]$max=90){ if([string]::IsNullOrWhiteSpace($t)){return ''}; if($t.Length -le $max){return $t}; return $t.Substring(0,$max)+'…' }

function Update-Recent([string]$file){
  $script:State.Recent = @($file) + ($script:State.Recent | Where-Object { $_ -ne $file })
  $script:State.Recent = $script:State.Recent | Select-Object -First 15
}

function Is-Favorite($file){ $script:State.Favorites -contains $file }
function Toggle-Favorite($file){ if(Is-Favorite $file){ $script:State.Favorites = $script:State.Favorites | Where-Object { $_ -ne $file } } else { $script:State.Favorites += $file }; Save-State }

# ---------------- XAML ----------------
$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Scripts Launcher" Height="720" Width="1280" WindowStartupLocation="CenterScreen" MinWidth="1000" MinHeight="600">
  <Grid Margin="8">
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="260"/>
      <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="220"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- Top Bar -->
    <DockPanel Grid.Row="0" Grid.ColumnSpan="2" LastChildFill="True" Margin="0 0 0 6">
      <StackPanel Orientation="Horizontal" DockPanel.Dock="Left">
        <Label Content="Filtro:" VerticalAlignment="Center"/>
        <TextBox x:Name="TxtFilter" Width="250" Margin="4 0"/>
        <CheckBox x:Name="ChkTests" Content="Testes" Margin="10 0"/>
        <CheckBox x:Name="ChkDry" Content="Dry-Run" Margin="6 0"/>
        <Button x:Name="BtnReload" Content="Recarregar" Margin="10 0"/>
        <Button x:Name="BtnTheme" Content="Tema" Margin="4 0"/>
        <Button x:Name="BtnSaveArgs" Content="Salvar Args" Margin="4 0"/>
      </StackPanel>
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
        <Button x:Name="BtnOpen" Content="Abrir" Margin="4 0"/>
        <Button x:Name="BtnRun" Content="Executar" Margin="4 0"/>
        <Button x:Name="BtnElev" Content="Elevado" Margin="4 0"/>
        <Button x:Name="BtnFav" Content="Favorito" Margin="10 0"/>
        <Button x:Name="BtnClose" Content="Fechar" Margin="18 0"/>
      </StackPanel>
    </DockPanel>

    <!-- Tree / Categories -->
    <Grid Grid.Row="1" Grid.Column="0">
      <Grid.RowDefinitions>
        <RowDefinition Height="*"/>
        <RowDefinition Height="160"/>
      </Grid.RowDefinitions>
      <GroupBox Header="Pastas" Grid.Row="0" Margin="0 0 0 6">
        <TreeView x:Name="TvFolders" />
      </GroupBox>
      <GroupBox Header="Recentes" Grid.Row="1">
        <ListBox x:Name="LbRecent" />
      </GroupBox>
    </Grid>

    <!-- Scripts list -->
    <DataGrid x:Name="GridScripts" Grid.Row="1" Grid.Column="1" AutoGenerateColumns="False" IsReadOnly="True" SelectionMode="Extended" SelectionUnit="FullRow" Margin="6 0 0 0">
      <DataGrid.Columns>
        <DataGridTextColumn Header="#" Binding="{Binding Index}" Width="40"/>
        <DataGridTextColumn Header="Nome" Binding="{Binding Name}" Width="200"/>
        <DataGridTextColumn Header="Pasta" Binding="{Binding Folder}" Width="200"/>
        <DataGridTextColumn Header="Descrição" Binding="{Binding ShortDescription}" Width="*"/>
        <DataGridTextColumn Header="Fav" Binding="{Binding FavFlag}" Width="50"/>
      </DataGrid.Columns>
    </DataGrid>

    <!-- Detalhes e Args -->
    <DockPanel Grid.Row="2" Grid.ColumnSpan="2" Margin="0 6 0 6">
      <Grid Margin="0 0 8 0">
        <Grid.RowDefinitions>
          <RowDefinition Height="*"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <TextBox x:Name="TxtDetails" Grid.Row="0" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" AcceptsReturn="True" IsReadOnly="True" FontFamily="Consolas"/>
        <TextBox x:Name="TxtArgs" Grid.Row="1" Margin="0 4 0 4" ToolTip="Argumentos específicos do script selecionado"/>
        <TextBlock x:Name="LblPath" Grid.Row="2" FontSize="11" Foreground="Gray" TextWrapping="Wrap"/>
      </Grid>
      <Grid Width="260">
        <Grid.RowDefinitions>
          <RowDefinition Height="*"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <GroupBox Header="Log" Grid.Row="0" Margin="0 0 0 4">
          <TextBox x:Name="TxtLog" AcceptsReturn="True" VerticalScrollBarVisibility="Auto" IsReadOnly="True" FontFamily="Consolas" TextWrapping="NoWrap"/>
        </GroupBox>
        <CheckBox x:Name="ChkAutoScroll" Grid.Row="1" Content="Auto Scroll" IsChecked="True"/>
      </Grid>
    </DockPanel>

    <!-- Status -->
    <StatusBar Grid.Row="3" Grid.ColumnSpan="2">
      <StatusBarItem><TextBlock x:Name="LblStatus" Text="Pronto"/></StatusBarItem>
      <StatusBarItem HorizontalAlignment="Right"><TextBlock x:Name="LblRoot" Text=""/></StatusBarItem>
    </StatusBar>
  </Grid>
</Window>
'@

$reader = (New-Object System.Xml.XmlNodeReader ([xml]$xaml))
$Window = [Windows.Markup.XamlReader]::Load($reader)

# Controles
$TxtFilter=$Window.FindName('TxtFilter');$ChkTests=$Window.FindName('ChkTests');$ChkDry=$Window.FindName('ChkDry')
$BtnReload=$Window.FindName('BtnReload');$BtnTheme=$Window.FindName('BtnTheme');$BtnSaveArgs=$Window.FindName('BtnSaveArgs')
$BtnOpen=$Window.FindName('BtnOpen');$BtnRun=$Window.FindName('BtnRun');$BtnElev=$Window.FindName('BtnElev');$BtnFav=$Window.FindName('BtnFav');$BtnClose=$Window.FindName('BtnClose')
$TvFolders=$Window.FindName('TvFolders');$LbRecent=$Window.FindName('LbRecent');$GridScripts=$Window.FindName('GridScripts')
$TxtDetails=$Window.FindName('TxtDetails');$TxtArgs=$Window.FindName('TxtArgs');$LblPath=$Window.FindName('LblPath')
$TxtLog=$Window.FindName('TxtLog');$ChkAutoScroll=$Window.FindName('ChkAutoScroll');$LblStatus=$Window.FindName('LblStatus');$LblRoot=$Window.FindName('LblRoot')

$ChkTests.IsChecked=[bool]$IncludeTests; $ChkDry.IsChecked=[bool]$DryRun; $LblRoot.Text=$RepoRoot
$script:ShowTests = [bool]$IncludeTests

function LogMsg([string]$m){ $line="$(Get-Date -Format 'HH:mm:ss') $m";$TxtLog.AppendText($line+[Environment]::NewLine); if($ChkAutoScroll.IsChecked){ $TxtLog.ScrollToEnd() } }

function Load-Scripts { $script:All = Discover-AllScripts; Build-FolderTree; Apply-Filter }

function Build-FolderTree {
  $TvFolders.Items.Clear()
  $grouped = $script:All | Group-Object Folder
  foreach($g in ($grouped | Sort-Object Name)){
    $node = New-Object System.Windows.Controls.TreeViewItem
    $label = if([string]::IsNullOrWhiteSpace($g.Name)){'(raiz)'} else { $g.Name }
    $node.Header = "$label ($($g.Count))"
    $node.Tag = $g.Name
    $TvFolders.Items.Add($node) | Out-Null
  }
}

function Apply-Filter {
  $filter = $TxtFilter.Text.Trim()
  $selectedFolder = ($TvFolders.SelectedItem)?.Tag
  $data = $script:All
  if($selectedFolder){ $data = $data | Where-Object { $_.Folder -eq $selectedFolder } }
  if(-not [string]::IsNullOrWhiteSpace($filter)){
    $data = $data | Where-Object { $_.Name -like "*${filter}*" -or $_.Description -like "*${filter}*" -or $_.Relative -like "*${filter}*" }
  }
  $GridScripts.ItemsSource = $null
  $i=1
  $GridScripts.ItemsSource = $data | Sort-Object Name | ForEach-Object {
    $fav = if(Is-Favorite $_.Full){ '★' } else { ' ' }
    $obj = [PSCustomObject]@{ Index=$i; Name=$_.Name; Folder=$_.Folder; ShortDescription=(Short $_.Description); Full=$_.Full; Relative=$_.Relative; FavFlag=$fav }
    $i++
    $obj
  }
  $LblStatus.Text = "$($data.Count) scripts"
}

function Update-Details {
  $sel = $GridScripts.SelectedItems
  if(-not $sel -or $sel.Count -eq 0){ $TxtDetails.Text='Selecione scripts.'; $TxtArgs.Text=''; $LblPath.Text=''; return }
  if($sel.Count -eq 1){
    $file = $sel[0].Full
    $TxtDetails.Text = (Get-Content -Path $file -TotalCount 80 -ErrorAction SilentlyContinue) -join [Environment]::NewLine
    $LblPath.Text = $file
    $TxtArgs.Text = ($script:State.PerScriptArgs[$file])
  } else {
    $TxtDetails.Text = "$($sel.Count) scripts selecionados."
    $LblPath.Text=''
    $TxtArgs.Text=''
  }
}

function Run-Scripts([switch]$Elevated){
  $sel = $GridScripts.SelectedItems
  if(-not $sel -or $sel.Count -eq 0){ LogMsg 'Nada selecionado.'; return }
  $pwsh = try { Get-Pwsh } catch { LogMsg $_; return }
  foreach($row in $sel){
    $file = $row.Full
    $argsLine = ''
    if($script:State.PerScriptArgs.ContainsKey($file) -and $script:State.PerScriptArgs[$file]){ $argsLine = $script:State.PerScriptArgs[$file] }
    if([string]::IsNullOrWhiteSpace($argsLine)){
      $cmd = "$pwsh -NoProfile -ExecutionPolicy Bypass -File `"$file`""
    } else {
      $cmd = "$pwsh -NoProfile -ExecutionPolicy Bypass -File `"$file`" $argsLine"
    }
    $cmd = $cmd.Trim()
    if($ChkDry.IsChecked){ LogMsg "(dry-run) $cmd"; continue }
    LogMsg "Executando: $cmd"
    try {
      if($Elevated){
        $argPart = $cmd.Substring($pwsh.Length).Trim()
        Start-Process -FilePath $pwsh -ArgumentList $argPart -Verb RunAs | Out-Null
        LogMsg 'Elevado iniciado.'
      } else {
        & $pwsh -NoProfile -ExecutionPolicy Bypass -File $file @($argsLine -split ' ')
        LogMsg "Concluído: $file"
      }
      Update-Recent $file
    } catch { LogMsg "Erro: $($_.Exception.Message)" }
  }
  Save-State
  Refresh-Recent
}

function Refresh-Recent {
  $LbRecent.Items.Clear()
  foreach($r in $script:State.Recent){ $LbRecent.Items.Add($r) | Out-Null }
}

function Apply-Theme {
  $dark = $script:State.DarkTheme
  $bg = if($dark){'#1e1e1e'} else {'White'}
  $fg = if($dark){'White'} else {'Black'}
  $Window.Background=$bg
  foreach($v in (Get-VisualChildren $Window)){ if($v -is [System.Windows.Controls.Control]){ $v.Foreground=$fg } }
}

function Get-VisualChildren([System.Windows.DependencyObject]$parent){ $c=[System.Windows.Media.VisualTreeHelper]::GetChildrenCount($parent); for($i=0;$i -lt $c;$i++){ $ch=[System.Windows.Media.VisualTreeHelper]::GetChild($parent,$i); if($ch){ $ch; Get-VisualChildren $ch } } }

function Toggle-Fav-Selected { $sel=$GridScripts.SelectedItems; if(-not $sel -or $sel.Count -ne 1){ LogMsg 'Selecione 1 script.'; return }; Toggle-Favorite $sel[0].Full; Apply-Filter }

function Save-Args { $sel=$GridScripts.SelectedItems; if($sel.Count -ne 1){ LogMsg 'Selecione 1 script para salvar args.'; return }; $file=$sel[0].Full; $script:State.PerScriptArgs[$file]=$TxtArgs.Text.Trim(); Save-State; LogMsg 'Args salvos.' }

function Open-File { $sel=$GridScripts.SelectedItems; if($sel.Count -ne 1){ LogMsg 'Selecione 1 script.'; return }; Start-Process -FilePath $sel[0].Full }

# Eventos
$TxtFilter.Add_TextChanged({ Apply-Filter })
$ChkTests.Add_Click({ $script:ShowTests=[bool]$ChkTests.IsChecked; Load-Scripts })
$BtnReload.Add_Click({ Load-Scripts })
$BtnTheme.Add_Click({ $script:State.DarkTheme = -not $script:State.DarkTheme; Save-State; Apply-Theme })
$BtnSaveArgs.Add_Click({ Save-Args })
$BtnOpen.Add_Click({ Open-File })
$BtnRun.Add_Click({ Run-Scripts })
$BtnElev.Add_Click({ Run-Scripts -Elevated })
$BtnFav.Add_Click({ Toggle-Fav-Selected })
$BtnClose.Add_Click({ $Window.Close() })
$TvFolders.Add_SelectedItemChanged({ Apply-Filter })
$GridScripts.Add_SelectionChanged({ Update-Details })
$LbRecent.Add_MouseDoubleClick({ param($s,$e) $item=$LbRecent.SelectedItem; if($item){ $TxtFilter.Text=''; $TvFolders.SelectedItem=$null; $target=$GridScripts.Items | Where-Object { $_.Full -eq $item }; if($target){ $GridScripts.SelectedItem=$target; Update-Details } } })

function Init-App { LogMsg "Raiz: $RepoRoot"; Load-Scripts; Refresh-Recent; Apply-Theme; Update-Details }

Init-App

[void]$Window.ShowDialog()
