#Requires -RunAsAdministrator
param([switch]$Apply,[switch]$Restore,[switch]$Fallback,[switch]$Reconcile,[switch]$Emergency,[Parameter(Mandatory)][switch]$AcceptLabChanges)
$ErrorActionPreference='Stop'
if(!$AcceptLabChanges -or (@($Apply,$Restore,$Fallback,$Reconcile | Where-Object {$_}).Count -ne 1)){throw 'Seleccione una operación y confirme AcceptLabChanges.'}
if($Restore -and !$Emergency){Import-Module "$PSScriptRoot/StrictControl.psm1" -Force;Assert-SentinelRemovalReady}
Import-Module "$PSScriptRoot/NetworkControl.psm1" -Force
Import-Module "$PSScriptRoot/DnsHealth.psm1" -Force
$data=Join-Path $env:ProgramData 'Sentinel'
$journal=Join-Path $data 'network-backup.json'
$lease=[IO.File]::Open((Join-Path $data 'network-operation.lock'),'OpenOrCreate','ReadWrite','None')
try{
 $backend=New-SentinelNetworkBackend
 if($Restore){
  if(Test-Path -LiteralPath $journal){Set-SentinelNetworkMode Restore $journal $backend}
  Clear-DnsClientCache;return
 }
 if($Fallback){
  if(!(Test-SentinelFilteredResolver '1.1.1.3') -or !(Test-SentinelFilteredResolver '1.0.0.3')){throw 'Los DNS filtrados de respaldo no superaron la prueba; no se cambia a un DNS sin filtro.'}
  Set-SentinelNetworkMode Fallback $journal $backend
  Clear-DnsClientCache;return
 }
 if((Get-Service Sentinel).Status -ne 'Running' -or !(Test-SentinelFilteredResolver)){throw 'El servicio local debe superar la prueba de filtrado.'}
 $rows=if(Test-Path -LiteralPath $journal){Get-Content -LiteralPath $journal -Raw | ConvertFrom-Json}else{@()}
 foreach($nic in Get-NetAdapter -Physical | Where-Object Status -eq 'Up'){
  if(@($rows | Where-Object Guid -eq $nic.InterfaceGuid.ToString()).Count){continue}
  $new=@()
  foreach($family in 'IPv4','IPv6'){
   $r=[pscustomobject]@{Guid=$nic.InterfaceGuid.ToString();Family=$family;Static='';Loop=$(if($family -eq 'IPv4'){'127.0.0.1'}else{'::1'});Done=$false}
   $current=& $backend.Read $r
   if($null -eq $current -or ![string]::IsNullOrWhiteSpace($current.Static)){throw 'Nuevo adaptador con DNS estático: requiere revisión; no se sobrescribe.'}
   $new+=$r
  }
  $rows+=$new
 }
 if(!$rows.Count){throw 'No hay adaptadores físicos activos compatibles.'}
 Save-SentinelNetworkJournal $journal $rows
 Set-SentinelNetworkMode Local $journal $backend
 Clear-DnsClientCache
}finally{$lease.Dispose()}
