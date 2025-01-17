# Versão melhorada do AdGuardDNS_simple.ps1
# Script para configurar o DNS AdGuard no Windows

# Verificação de permissões de administrador
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Este script precisa ser executado como administrador."
    Write-Host "Reiniciando script no Terminal com o perfil PowerShell Preview..."
    Start-Sleep -Seconds 2 # Pausa de 2 segundos para exibir a mensagem

    # Reabrindo o script no perfil correto
    Start-Process "wt.exe" `
        -ArgumentList "new-tab -p `"{4856f5c3-1628-4641-a55d-7394620557be}`" pwsh -NoProfile -File `"$PSCommandPath`"" `
        -Verb RunAs

    exit
}

# AdGuard IPs DNS
$ipv4PrimaryDNS = "94.140.14.14"
$ipv4SecondaryDNS = "94.140.15.15"
$ipv6PrimaryDNS = "2a10:50c0::ad1:ff"
$ipv6SecondaryDNS = "2a10:50c0::ad2:ff"

# Interface de rede
$interface = "Ethernet 1"

# Pergunta qual opção deseja realizar
$opcao = Read-Host "Escolha a opção desejada: 1 - Configurar DNS AdGuard, 2 - Restaurar DNS original"

# Confirmação da escolha
$confirmacao = Read-Host "Você escolheu a opção $opcao. Deseja continuar? (s/n)"
if ($confirmacao -ne 's') {
    Write-Host "Operação cancelada pelo usuário."
    exit
}

# Configuração do DNS AdGuard
try {
    if ($opcao -eq 1) {
        Write-Host "Configurando DNS AdGuard..."
        Write-Host "Configurando IPv4 Primary DNS: $ipv4PrimaryDNS"
        netsh interface ipv4 set dns $interface static $ipv4PrimaryDNS
        Write-Host "Configurando IPv4 Secondary DNS: $ipv4SecondaryDNS"
        netsh interface ipv4 add dns $interface $ipv4SecondaryDNS index=2
        Write-Host "Configurando IPv6 Primary DNS: $ipv6PrimaryDNS"
        netsh interface ipv6 set dns $interface static $ipv6PrimaryDNS
        Write-Host "Configurando IPv6 Secondary DNS: $ipv6SecondaryDNS"
        netsh interface ipv6 add dns $interface $ipv6SecondaryDNS index=2
        Write-Host "DNS AdGuard configurado com sucesso!"
    }
    # Restaurar DNS original
    elseif ($opcao -eq 2) {
        Write-Host "Restaurando DNS original..."
        Write-Host "Restaurando IPv4 DNS para DHCP"
        netsh interface ipv4 set dns $interface dhcp
        Write-Host "Restaurando IPv6 DNS para DHCP"
        netsh interface ipv6 set dns $interface dhcp
        Write-Host "DNS restaurado com sucesso!"
    }
    else {
        Write-Host "Opção inválida!"
    }
}
catch {
    Write-Host "Erro ao configurar DNS: $_"
}

# Opção para verificar os IPs DNS atuais
$verificarDNS = Read-Host "Deseja verificar os IPs DNS atuais? (s/n)"
if ($verificarDNS -eq 's') {
    Write-Host "IPs DNS atuais para ${interface}:"
    netsh interface ipv4 show dnsservers $interface
    netsh interface ipv6 show dnsservers $interface
}

# Pause
Write-Host "Pressione qualquer tecla para sair..."
$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null

# Fim do script
exit
