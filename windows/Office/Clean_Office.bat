@echo off
taskkill /im explorer.exe /f
Takeown /f  %temp% /R /D N 
icacls %temp% /E /T /G Todos:F 
RD /S %temp% /q 
del %temp% /q
Takeown /f  "%windir%\temp" /R /D N 
icacls "%windir%\temp" /E /T /G Todos:F 
RD /S "%windir%\temp" /q 
del "%windir%\temp" /q
Takeown /f  "%windir%\prefetch" /R /D N 
icacls "%windir%\prefetch" /E /T /G Todos:F 
RD /S "%windir%\prefetch" /q 
del "%windir%\prefetch" /q
Takeown /f  %userprofile%\recent" /R /D N 
icacls %userprofile%\recent" /E /T /G Todos:F 
RD /S %userprofile%\recent" /q 
del %userprofile%\recent" /q
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 8
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 2
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 1
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 16
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 32
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 255
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 4351
ipconfig /release  
ipconfig /renew 
ipconfig /flushdns 
Netsh winsock reset 
net localgroup administradores localservice /add  
fsutil resource setautoreset true C:\  
netsh int ip reset resetlog.txt  
netsh winsock reset all 
netsh int 6to4 reset all 
Netsh int ip reset all 
netsh int ipv4 reset all 
netsh int ipv6 reset all 
netsh int httpstunnel reset all 
netsh int isatap reset all 
netsh int portproxy reset all 
netsh int tcp reset all  
netsh int teredo reset all 
Netsh int ip reset  
Netsh winsock reset  
netsh interface teredo set state disabled
netsh interface ipv6 6to4 set state state=disabled undoonstop=disabled
netsh interface ipv6 isatap set state state=disabled
DIR "%systemdrive%" | Find "Windows.old"
if %ERRORLEVEL% EQU 1 GOTO :Remover
if %ERRORLEVEL% EQU 0 GOTO :NaoRemover
GOTO :Windows10Upgrade
:Remover
Takeown /f  "%systemdrive%\Windows.old" /R /D N 
icacls "%systemdrive%\Windows.old" /E /T /G Todos:F 
RD /S "%systemdrive%\Windows.old" /q 
del "%systemdrive%\Windows.old" /q
GOTO :Windows10Upgrade
:NaoRemover
GOTO :Windows10Upgrade
:Windows10Upgrade
@Echo off
DIR "%systemdrive%" | Find "Windows10Upgrade"
if %ERRORLEVEL% EQU 1 GOTO :Remover
if %ERRORLEVEL% EQU 0 GOTO :NaoRemover
GOTO :WindowsUpgrade
:Remover
Takeown /f  "%systemdrive%\Windows10Upgrade" /R /D N 
icacls "%systemdrive%\Windows10Upgrade" /E /T /G Todos:F 
RD /S "%systemdrive%\Windows10Upgrade" /q 
del "%systemdrive%\Windows10Upgrade" /q
DEL "%systemdrive%\ProgramData\Microsoft\Windows\Start Menu\Programs\Windows 10 Update Assistant.lnk"
DEL "%systemdrive%\ProgramData\Microsoft\Windows\Start Menu\Programs\Assistente de Atualização do Windows 10.lnk"
DEL "%userprofile%\Desktop\Windows 10 Update Assistant.lnk"
DEL "%userprofile%\Desktop\Assistente de Atualização do Windows 10.lnk"
GOTO :WindowsUpgrade
:NaoRemover
GOTO :WindowsUpgrade
:WindowsUpgrade
@Echo off
DIR "%systemdrive%" | Find "WindowsUpgrade"
if %ERRORLEVEL% EQU 1 GOTO :Remover
if %ERRORLEVEL% EQU 0 GOTO :NaoRemover
GOTO :Explorer
:Remover
Takeown /f  "%systemdrive%\WindowsUpgrade" /R /D N 
icacls "%systemdrive%\WindowsUpgrade" /E /T /G Todos:F 
RD /S "%systemdrive%\WindowsUpgrade" /q 
del "%systemdrive%\WindowsUpgrade" /q
DEL "%systemdrive%\ProgramData\Microsoft\Windows\Start Menu\Programs\Windows 10 Update Assistant.lnk"
DEL "%systemdrive%\ProgramData\Microsoft\Windows\Start Menu\Programs\Assistente de Atualização do Windows 10.lnk"
DEL "%userprofile%\Desktop\Windows 10 Update Assistant.lnk"
DEL "%userprofile%\Desktop\Assistente de Atualização do Windows 10.lnk"
GOTO :Explorer
:NaoRemover
GOTO :Explorer
:Explorer
start explorer.exe
exit