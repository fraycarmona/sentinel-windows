#Requires -RunAsAdministrator
param([Parameter(Mandatory)][switch]$AcceptLabChanges)
$ErrorActionPreference='Stop'
if(!$AcceptLabChanges){throw 'Se requiere consentimiento para los cambios en la VM.'}
$source=Split-Path $PSScriptRoot
$target=Join-Path $env:ProgramFiles 'Sentinel'
$data=Join-Path $env:ProgramData 'Sentinel'
if((Test-Path $target) -or (Test-Path $data) -or (Get-Service Sentinel -ErrorAction SilentlyContinue)){throw 'Existe una instalación o recuperación pendiente. No se sobrescribe.'}
if(Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Sentinel'){throw 'Existe una entrada previa de desinstalación.'}
if((Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name Sentinel -ErrorAction SilentlyContinue).Sentinel){throw 'Existe una entrada previa de inicio automático.'}
if(!(Test-Path "$source/dist/Service/Sentinel.Service.exe")){throw 'Compile con -Publish primero.'}
New-Item -ItemType Directory $target,$data | Out-Null
# ACLs by SID avoid localized account names. LocalService runs DNS without elevation.
& icacls.exe $data /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-19:(OI)(CI)M' | Out-Null
if($LASTEXITCODE){throw 'No se pudo proteger el directorio de estado'}
Copy-Item "$source/dist/Service" "$target/Service" -Recurse
Copy-Item "$source/dist/UI" "$target/UI" -Recurse
Copy-Item "$source/scripts" "$target/scripts" -Recurse
Copy-Item "$source/docs" "$target/docs" -Recurse
[IO.File]::WriteAllText("$data/lock.json",'null')
[IO.File]::WriteAllText("$data/owner.txt",[Security.Principal.WindowsIdentity]::GetCurrent().User.Value)
Copy-Item "$source/config/rules.json" "$data/rules.json"
& sc.exe create Sentinel binPath= ('"'+$target+'\Service\Sentinel.Service.exe"') start= auto obj= 'NT AUTHORITY\LocalService' DisplayName= 'SENTINEL — protección DNS'
if($LASTEXITCODE){throw 'No se pudo crear el servicio. Conserve los archivos para diagnóstico.'}
& sc.exe description Sentinel 'Resolvedor DNS voluntario. Recuperación documentada en Program Files\Sentinel\docs.'
& sc.exe failure Sentinel reset= 86400 actions= restart/10000/restart/30000/none/0
Start-Service Sentinel
$uninstall='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Sentinel'
if(Test-Path $uninstall){throw 'Existe una entrada de desinstalación ajena; no se sobrescribe.'}
New-Item $uninstall -Force | Out-Null
New-ItemProperty $uninstall DisplayName -Value 'SENTINEL - protección DNS' -PropertyType String | Out-Null
New-ItemProperty $uninstall DisplayVersion -Value '0.3.0' -PropertyType String | Out-Null
New-ItemProperty $uninstall UninstallString -Value ('"'+$target+'\UI\SENTINEL.exe" --uninstall') -PropertyType String | Out-Null
New-ItemProperty $uninstall DisplayIcon -Value ($target+'\UI\SENTINEL.exe') -PropertyType String | Out-Null
New-ItemProperty $uninstall NoModify -Value 1 -PropertyType DWord | Out-Null
New-ItemProperty $uninstall NoRepair -Value 1 -PropertyType DWord | Out-Null
# Visible per-user startup; the service itself uses SCM automatic start independently.
$run='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
New-Item $run -Force | Out-Null
New-ItemProperty $run Sentinel -Value ('"'+$target+'\UI\SENTINEL.exe"') -PropertyType String -Force | Out-Null
Write-Host 'Servicio instalado. La red aún no se ha cambiado. Ejecute network-lab.ps1 -Apply -AcceptLabChanges para el piloto.'
