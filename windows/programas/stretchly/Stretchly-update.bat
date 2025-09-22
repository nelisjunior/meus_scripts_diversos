@echo off
certutil -urlcache -split -f "https://github.com/hovancik/stretchly/releases/latest/download/Stretchly-Setup-1.15.1.exe" "D:\Users\Nelis\Softwares\Windows tools\Stretchly-Setup-1.15.1.exe"
cd D:\Users\Nelis\Softwares\Windows tools\
Stretchly-Setup-1.15.1.exe /S /allusers