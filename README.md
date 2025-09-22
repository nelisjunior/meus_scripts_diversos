# meus_scripts_diversos

Repositório público de scripts diversos em PowerShell e Batchfile para automação e administração de sistemas Windows.

## Objetivo

Centralizar scripts úteis para tarefas do dia a dia, como configuração de rede, instalação de softwares, manutenção e automatização de procedimentos administrativos no Windows.

## Estrutura

Os scripts estão organizados em subpastas temáticas:
- `windows/menu/`: Menu interativo para descoberta e execução dos demais scripts.
- `windows/Administrador/`: Scripts administrativos (ex: WSL_Cleanup, PowerShell_update).
- `windows/rede/`: Scripts de configuração de rede (ex: AdGuard DNS).
- `windows/navegadores/edge/`: Backup e restauração de extensões do Edge.
- `windows/programas/stretchly/`: Instalação e update silencioso do Stretchly.
- `windows/Office/`: Limpeza/remoção de componentes do Office.

## Exemplos de Scripts

### 1. Atualização do PowerShell

Script para baixar e instalar automaticamente uma versão específica do PowerShell:

```powershell
$url = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.1/PowerShell-7.4.1-win-x64.msi"
$output = "C:\Caminho\Para\Salvar\PowerShell-7.4.1-win-x64.msi"  # Altere para o diretório desejado
Invoke-WebRequest -Uri $url -OutFile $output
Start-Process -FilePath $output -ArgumentList "/S /allusers" -Wait
```

### 2. Configuração de DNS AdGuard

Script interativo para configurar rapidamente o DNS AdGuard em uma interface de rede do Windows, com opção de restaurar DNS original:

```powershell
# Executar como administrador
# Escolha: 1 - Configurar DNS AdGuard, 2 - Restaurar DNS original

$ipv4PrimaryDNS = "94.140.14.14"
$ipv4SecondaryDNS = "94.140.15.15"
$ipv6PrimaryDNS = "2a10:50c0::ad1:ff"
$ipv6SecondaryDNS = "2a10:50c0::ad2:ff"
$interface = "Ethernet 1"
# ... restante do script disponível no repositório
```

## Como usar

1. Faça o clone do repositório:
   ```bash
   git clone https://github.com/nelisjunior/meus_scripts_diversos.git
   ```
2. Navegue até o diretório do script desejado.
3. Execute o script conforme instruções e permissões necessárias (alguns scripts exigem execução como administrador).

### Menu Visual (GUI)

Para iniciar a interface gráfica (Windows Forms):

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\windows\menu\ScriptsMenu.GUI.ps1
```

Recursos:
- Filtro por nome
- Visualização do conteúdo
- Execução normal ou elevada
- Múltipla seleção
- Campo de argumentos (aplicado a todos os selecionados)
- Modo Dry-Run (marcar checkbox)

Use a versão de console (`ScriptsMenu.ps1`) caso prefira ambiente puramente terminal ou precise de máxima compatibilidade remota.

## Contribuição

Sugestões, correções e novos scripts são bem-vindos! Abra uma issue ou envie um pull request.

---

**Atenção:** Execute scripts de fontes confiáveis e revise o código antes de rodar em ambientes de produção.

> Veja todos os scripts do repositório navegando pelas pastas ou acesse pelo [GitHub Code Search](https://github.com/search?q=repo%3Anelisjunior%2Fmeus_scripts_diversos).
