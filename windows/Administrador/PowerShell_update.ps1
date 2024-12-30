$url = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.1/PowerShell-7.4.1-win-x64.msi"
$output = "D:\Users\Nelis\Softwares\Windows tools\PowerShell-7.4.1-win-x64.msi"
Invoke-WebRequest -Uri $url -OutFile $output
Start-Process -FilePath $output -ArgumentList "/S /allusers" -Wait

