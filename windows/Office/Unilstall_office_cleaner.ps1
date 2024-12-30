# Desinstalar o Office 365
Get-AppxPackage *Office* | Remove-AppxPackage

# Remover arquivos remanescentes de usuário
Remove-Item "C:\Users\%userprofile%\AppData\Local\Microsoft\Office" -Recurse -Force
Remove-Item "C:\Users\%userprofile%\AppData\Local\Microsoft\Office\15.0" -Recurse -Force
Remove-Item "C:\ProgramData\Microsoft\Office" -Recurse -Force

# Remove arquivos de registro
Get-ChildItem "HKLM:\Software\Microsoft\Office" -Recurse | Remove-Item -Recurse -Force
Get-ChildItem "HKCU:\Software\Microsoft\Office" -Recurse | Remove-Item -Recurse -Force

# Remover arquivos de configuração
Get-ChildItem "C:\ProgramData\Microsoft\Office\ClientRulesEngine" -Recurse | Remove-Item -Recurse -Force
Get-ChildItem "C:\ProgramData\Microsoft\Office\Office Setup" -Recurse | Remove-Item -Recurse -Force

# Remover arquivos temporários
Get-ChildItem "C:\Users\%userprofile%\AppData\Local\Temp\Office" -Recurse | Remove-Item -Recurse -Force

# Remover atalhos
Get-ChildItem "C:\Users\%userprofile%\Desktop\Office" -Recurse | Remove-Item -Recurse -Force
Get-ChildItem "C:\Users\%userprofile%\Start Menu\Programs\Microsoft Office" -Recurse | Remove-Item -Recurse -Force

# Remove arquivos das pastas genéricas
Remove-Item "C:\Program Files\Microsoft Office" -Recurse -Force
Remove-Item "C:\Program Files\Microsoft Office 15" -Recurse -Force
Remove-Item "C:\Program Files\Microsoft Office 16" -Recurse -Force
