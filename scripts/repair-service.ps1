#Requires -RunAsAdministrator
$ErrorActionPreference='Stop'
$source=Split-Path $PSScriptRoot
$target=Join-Path $env:ProgramFiles 'Sentinel'
$image=(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\Sentinel').ImagePath
if($image.Trim('"') -ine [IO.Path]::GetFullPath((Join-Path $target 'Service/Sentinel.Service.exe'))){throw 'La ruta del servicio no corresponde a esta instalación; no se modifica.'}
if($source -ine $target -and !(Test-Path "$source/dist/Service/Sentinel.Service.exe")){throw 'Falta el servicio compilado para reparar.'}
# Restore before replacing an existing resolver, preserving its wait and rules.
if(Test-Path (Join-Path $env:ProgramData 'Sentinel/network-backup.json')){
 & "$PSScriptRoot/network-lab.ps1" -Restore -Emergency -AcceptLabChanges
}
Stop-Service Sentinel -ErrorAction Stop
(Get-Service Sentinel).WaitForStatus('Stopped',[TimeSpan]::FromSeconds(15))
$backup=Join-Path $target ('Backup-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory $backup | Out-Null
Copy-Item "$target/Service" "$backup/Service" -Recurse
Copy-Item "$target/scripts" "$backup/scripts" -Recurse
try{
 if($source -ine $target){
  Copy-Item "$source/dist/Service/*" "$target/Service" -Recurse -Force
  Copy-Item "$source/scripts/*" "$target/scripts" -Force
 }
 Start-Service Sentinel
 (Get-Service Sentinel).WaitForStatus('Running',[TimeSpan]::FromSeconds(15))
}catch{
 Stop-Service Sentinel -ErrorAction SilentlyContinue
 Copy-Item "$backup/Service/*" "$target/Service" -Recurse -Force
 throw 'Reparación incompleta. DNS restaurado; copia anterior conservada. Consulte la recuperación.'
}
& "$target/scripts/register-guardian.ps1"
