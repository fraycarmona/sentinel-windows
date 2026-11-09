param([string]$Data=(Join-Path $env:TEMP 'Sentinel-Demo'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
New-Item -ItemType Directory -Force $Data | Out-Null
if(!(Test-Path "$Data/lock.json")){[IO.File]::WriteAllText("$Data/lock.json",'null')}
[IO.File]::WriteAllText("$Data/owner.txt",[Security.Principal.WindowsIdentity]::GetCurrent().User.Value)
Copy-Item "$root/config/rules.json" "$Data/rules.json" -Force
Write-Host 'Demo local en puerto 1053. No cambia DNS, firewall ni servicios. Ctrl+C para detener.'
& "$root/dist/Service/Sentinel.Service.exe" --console --data $Data
