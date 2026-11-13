#Requires -RunAsAdministrator
$ErrorActionPreference='Stop'
$source=Split-Path $PSScriptRoot
$target=Join-Path $env:ProgramFiles 'Sentinel'
$data=Join-Path $env:ProgramData 'Sentinel'
$image=(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\Sentinel').ImagePath
if($image.Trim('"') -ine [IO.Path]::GetFullPath((Join-Path $target 'Service/Sentinel.Service.exe'))){throw 'Ruta del servicio ajena; no se modifica.'}
if($source -ine $target -and !(Test-Path "$source/dist/Service/Sentinel.Service.exe")){throw 'Falta servicio compilado.'}
Import-Module "$PSScriptRoot/Maintenance.psm1" -Force
$lease=Enter-SentinelMaintenance
$backup=Join-Path $target ('Backup-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
try{
 # Keep category filtering while replacing the resolver; never restore open DNS here.
 if(Test-Path "$data/network-backup.json"){& "$PSScriptRoot/network-lab.ps1" -Fallback -AcceptLabChanges}
 $old=Get-ScheduledTask -TaskName SentinelDnsRecovery -ErrorAction SilentlyContinue
 if($old){Stop-ScheduledTask -TaskName SentinelDnsRecovery}
 Stop-Service Sentinel -ErrorAction Stop
 (Get-Service Sentinel).WaitForStatus('Stopped',[TimeSpan]::FromSeconds(15))
 New-Item -ItemType Directory $backup | Out-Null
 Copy-Item "$target/Service" "$backup/Service" -Recurse
 Copy-Item "$target/scripts" "$backup/scripts" -Recurse
 if($source -ine $target){
  Copy-Item "$source/dist/Service/*" "$target/Service" -Recurse -Force
  Copy-Item "$source/scripts/*" "$target/scripts" -Force
  # Close only installed Sentinel UI processes to update their files, never browsers.
  Get-Process SENTINEL -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq "$target\UI\SENTINEL.exe"} | Stop-Process
  Copy-Item "$source/dist/UI/*" "$target/UI" -Recurse -Force
 }
 & "$target/scripts/merge-rules.ps1"
 & "$target/scripts/protect-state.ps1"
 & sc.exe config Sentinel start= auto | Out-Null
 if($LASTEXITCODE){throw 'No se pudo registrar inicio automático.'}
 & sc.exe failure Sentinel reset= 86400 actions= restart/10000/restart/30000/restart/60000 | Out-Null
 if($LASTEXITCODE){throw 'No se pudo registrar recuperación del motor.'}
 Start-Service Sentinel
 (Get-Service Sentinel).WaitForStatus('Running',[TimeSpan]::FromSeconds(15))
 & "$target/scripts/register-ui.ps1"
}catch{
 # Do not roll back across the protected-state migration: leave filtered DNS and diagnostic backup.
 throw "Actualización incompleta: $($_.Exception.Message). Respaldo filtrado y copia conservados; revisar recuperación."
}finally{
 $lease.Dispose()
 if(Test-Path "$target/scripts/register-guardian.ps1"){& "$target/scripts/register-guardian.ps1"}
}
