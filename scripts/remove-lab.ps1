#Requires -RunAsAdministrator
param([switch]$Emergency,[Parameter(Mandatory)][switch]$AcceptLabChanges)
$ErrorActionPreference='Stop'
if(!$AcceptLabChanges){throw 'Confirmación requerida'}
Import-Module "$PSScriptRoot/StrictControl.psm1" -Force
Import-Module "$PSScriptRoot/Maintenance.psm1" -Force
$lease=Enter-SentinelMaintenance
try{
if(!$Emergency){Assert-SentinelRemovalReady}
# Authorize the entire transaction before mutation. A concurrent cancellation
# must not interrupt restoration after the first journal has been processed.
if(Test-Path (Join-Path $env:ProgramData 'Sentinel/hosts-backup.json')){
 & "$PSScriptRoot/hosts-lab.ps1" -Mode Restore -Emergency
}
if(Test-Path (Join-Path $env:ProgramData 'Sentinel/strict-backup.json')){
 & "$PSScriptRoot/strict-lab.ps1" -Mode Restore -Emergency -AcceptLabChanges
}
# Restore BEFORE stopping the resolver. Errors leave service available for recovery.
& "$PSScriptRoot/network-lab.ps1" -Restore -Emergency -AcceptLabChanges
& "$PSScriptRoot/browser-lab.ps1" -Restore -Emergency -AcceptLabChanges
$guardianScript=Join-Path $env:ProgramFiles 'Sentinel/scripts/dns-guardian.ps1'
$guardianArguments=@(
 ('-NoProfile -NonInteractive -File "'+$guardianScript+'"')
 ('-NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File "'+$guardianScript+'"')
)
$recovery=Get-ScheduledTask -TaskName SentinelDnsRecovery -ErrorAction SilentlyContinue
if($recovery -and @($recovery.Actions).Count -eq 1 -and $recovery.Actions[0].Arguments -in $guardianArguments){
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

}finally{$lease.Dispose()}
