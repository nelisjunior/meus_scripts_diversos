function Set-DNSCustom {
    param (
        [string]$adapter,
        [string]$ipv4Primary,
        [string]$ipv4Secondary,
        [string]$ipv6Primary,
        [string]$ipv6Secondary
    )
    Write-Host "Configurando DNS personalizado para o adaptador $adapter..."
    Set-DnsClientServerAddress -InterfaceAlias $adapter -ServerAddresses $ipv4Primary, $ipv4Secondary
    Set-DnsClientServerAddress -InterfaceAlias $adapter -ServerAddresses $ipv6Primary, $ipv6Secondary
    Write-Host "DNS personalizado configurado com sucesso."
}

function Restore-DNSAuto {
    param (
        [string]$adapter
    )
    Write-Host "Restaurando configurações automáticas de DNS para o adaptador $adapter..."
    Set-DnsClientServerAddress -InterfaceAlias $adapter -ResetServerAddresses
    Write-Host "Configurações automáticas de DNS restauradas com sucesso."
}

function Restart-NetworkAdapter {
    param (
        [string]$adapter
    )
    Write-Host "Reiniciando o adaptador de rede $adapter..."
    Disable-NetAdapter -Name $adapter -Confirm:$false
    Start-Sleep -Seconds 5
    Enable-NetAdapter -Name $adapter -Confirm:$false
    Write-Host "Adaptador de rede reiniciado com sucesso."
}

$adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1

$ipv4Primary = "94.140.14.14"
$ipv4Secondary = "94.140.15.15"
$ipv6Primary = "2a10:50c0::ad1:ff"
$ipv6Secondary = "2a10:50c0::ad2:ff"

if (-not $adapter) {
    Write-Host "Adaptador não detectado. Certifique-se de que o adaptador está corretamente configurado."
    exit
}

Write-Host "Adaptador detectado: $($adapter.Name)"
Write-Host "======================================"
Write-Host "Configuração de DNS"
Write-Host "======================================"
Write-Host "1. Ativar DNS personalizado (AdGuard DNS)"
Write-Host "2. Restaurar configurações automáticas"
Write-Host "======================================"
$choice = Read-Host "Escolha uma opção (1 ou 2)"

try {
    if ($choice -eq "1") {
        Set-DNSCustom -adapter $adapter.Name -ipv4Primary $ipv4Primary -ipv4Secondary $ipv4Secondary -ipv6Primary $ipv6Primary -ipv6Secondary $ipv6Secondary
        Restart-NetworkAdapter -adapter $adapter.Name
    } elseif ($choice -eq "2") {
        Restore-DNSAuto -adapter $adapter.Name
        Restart-NetworkAdapter -adapter $adapter.Name
    } else {
        Write-Host "Opção inválida. Tente novamente."
    }
} catch {
    Write-Host "Ocorreu um erro: $_"
}