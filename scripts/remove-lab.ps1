#Requires -RunAsAdministrator
param([switch]$Emergency,[Parameter(Mandatory)][switch]$AcceptLabChanges)
$ErrorActionPreference='Stop'
if(!$AcceptLabChanges){throw 'Confirmación requerida'}
Import-Module "$PSScriptRoot/StrictControl.psm1" -Force
if(!$Emergency){Assert-SentinelRemovalReady}
if(Test-Path (Join-Path $env:ProgramData 'Sentinel/strict-backup.json')){
 & "$PSScriptRoot/strict-lab.ps1" -Mode Restore -Emergency:$Emergency -AcceptLabChanges
}
# Restore BEFORE stopping the resolver. Errors leave service available for recovery.
& "$PSScriptRoot/network-lab.ps1" -Restore -Emergency:$Emergency -AcceptLabChanges
& "$PSScriptRoot/browser-lab.ps1" -Restore -Emergency:$Emergency -AcceptLabChanges
$recovery=Get-ScheduledTask -TaskName SentinelDnsRecovery -ErrorAction SilentlyContinue
if($recovery -and @($recovery.Actions | Where-Object {$_.Arguments -eq ('-NoProfile -NonInteractive -File "'+(Join-Path $env:ProgramFiles 'Sentinel/scripts/dns-guardian.ps1')+'"')}).Count){
 Stop-ScheduledTask -TaskName SentinelDnsRecovery
 Unregister-ScheduledTask -TaskName SentinelDnsRecovery -Confirm:$false
}
if(Get-Service Sentinel -ErrorAction SilentlyContinue){Stop-Service Sentinel; & sc.exe delete Sentinel;if($LASTEXITCODE){throw 'No se pudo retirar el servicio'}}
$target=Join-Path $env:ProgramFiles 'Sentinel'
$run='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
if((Get-ItemProperty $run -Name Sentinel -ErrorAction SilentlyContinue).Sentinel -eq ('"'+$target+'\UI\SENTINEL.exe"')){Remove-ItemProperty $run -Name Sentinel}
$uninstall='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Sentinel'
if((Get-ItemProperty $uninstall -Name UninstallString -ErrorAction SilentlyContinue).UninstallString -eq ('"'+$target+'\UI\SENTINEL.exe" --uninstall')){Remove-Item -LiteralPath $uninstall}
Write-Host 'Servicio retirado; copia y estado conservados para diagnóstico. Puede eliminar Program Files\Sentinel y ProgramData\Sentinel tras verificar la conectividad.'
