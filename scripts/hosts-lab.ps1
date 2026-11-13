#Requires -RunAsAdministrator
param([ValidateSet('Apply','Restore')][string]$Mode='Apply',[switch]$Emergency)
$ErrorActionPreference='Stop'
Import-Module "$PSScriptRoot/HostsControl.psm1" -Force
$data=Join-Path $env:ProgramData 'Sentinel'
$path=Join-Path $env:WINDIR 'System32/drivers/etc/hosts'
$configured=[Environment]::ExpandEnvironmentVariables((Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters').DataBasePath)
if([IO.Path]::GetFullPath($configured).TrimEnd('\') -ine (Split-Path $path)){throw 'Ruta hosts personalizada: requiere revisión; no se modifica.'}
$journal=Join-Path $data 'hosts-backup.json'
if($Mode -eq 'Apply'){
 $rules=Get-Content "$data/rules.json" -Raw | ConvertFrom-Json
 # Residual exact-host protection; DNS engine still covers subdomains.
 $domains=@($rules.Deny | Where-Object {$_ -ne 'blocked.test'})
 if(@($rules.Allow).Count){throw 'Excepciones presentes: revisar antes de aplicar hosts residual.'}
 Add-SentinelHosts $path $journal $domains
}else{
 if(!$Emergency){Import-Module "$PSScriptRoot/StrictControl.psm1" -Force;Assert-SentinelRemovalReady}
 Remove-SentinelHosts $path $journal
}
Clear-DnsClientCache
