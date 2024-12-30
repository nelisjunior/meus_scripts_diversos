$url = "https://github.com/hovancik/stretchly/releases/latest/download/Stretchly-Setup-1.15.1.exe"
$output = "D:\Users\Nelis\Softwares\Windows tools\Stretchly-Setup-1.15.1.exe"
Invoke-WebRequest -Uri $url -OutFile $output
Start-Process -FilePath $output -ArgumentList "/S /allusers" -Wait


