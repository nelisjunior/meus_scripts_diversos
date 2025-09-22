# Administrador - Scripts e Menu

Este diretório contém utilitários e um menu interativo para gerenciar e executar scripts PowerShell do repositório.

Arquivos principais:

- `WSL_Cleanup.ps1` — Script para limpar instalações/resíduos do WSL (inclui opções `-Force` e `-DryRun`).
- `ScriptsMenu.ps1` — Menu interativo que lista os `.ps1` do repositório, permite visualizar e executar (normal ou elevado).
- `run_menu.bat` — Atalho para abrir o `ScriptsMenu.ps1` em uma nova janela do PowerShell (não elevado).
- `run_menu_elevated.bat` — Atalho para abrir o `ScriptsMenu.ps1` em modo elevado (Executar como Administrador).

Como usar

1. Abrir o menu (não elevado):

```pwsh
# Em Windows, execute o arquivo .bat ou execute diretamente no PowerShell
D:\nelis_repositorios\meus_scripts_diversos\windows\Administrador\run_menu.bat
```

2. Abrir o menu elevado (quando precisar executar scripts que exigem Admin):

```pwsh
D:\nelis_repositorios\meus_scripts_diversos\windows\Administrador\run_menu_elevated.bat
```

3. No menu, escolha o número do script e então:
- `v` — visualizar o conteúdo
- `e` — executar no mesmo shell (pode pedir argumentos)
- `u` — executar elevado (start-process -verb runAs)

Exemplo de execução do `WSL_Cleanup.ps1` diretamente (dry-run):

```pwsh
pwsh -NoProfile -ExecutionPolicy Bypass -File "D:\nelis_repositorios\meus_scripts_diversos\windows\Administrador\WSL_Cleanup.ps1" -DryRun
```

Ou para executar sem prompts:

```pwsh
pwsh -NoProfile -ExecutionPolicy Bypass -File "D:\nelis_repositorios\meus_scripts_diversos\windows\Administrador\WSL_Cleanup.ps1" -Force
```

Notas

- Abra sempre um PowerShell com permissões de Administrador quando for necessário (o script `WSL_Cleanup.ps1` exige privilégios para algumas operações).
- Se o seu ambiente usa `powershell.exe` (Windows PowerShell) em vez de `pwsh` (PowerShell 7+), os atalhos ainda funcionarão pois usam `pwsh` quando disponível e caem para `powershell` caso contrário.

Se quiser que eu adicione logs em arquivo ou um instalador/atalho no menu Iniciar, eu posso adicionar também.
