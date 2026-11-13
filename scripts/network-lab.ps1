#Requires -RunAsAdministrator
param([switch]$Apply,[switch]$Restore,[switch]$Emergency,[Parameter(Mandatory)][switch]$AcceptLabChanges)
$ErrorActionPreference='Stop'
if($Restore -and !$Emergency){Import-Module "$PSScriptRoot/StrictControl.psm1" -Force;Assert-SentinelRemovalReady}
if(!$AcceptLabChanges -or ($Apply -eq $Restore)){throw 'Seleccione Apply o Restore y confirme AcceptLabChanges.'}
$data=Join-Path $env:ProgramData 'Sentinel'
$journal=Join-Path $data 'network-backup.json'
function Save-Journal($rows){
 $json=ConvertTo-Json -InputObject @($rows) -Depth 8
 [IO.File]::WriteAllText("$journal.tmp",$json)
 Move-Item -LiteralPath "$journal.tmp" -Destination $journal -Force
}
if($Apply){
 if((Get-Service Sentinel).Status -ne 'Running'){throw 'El servicio debe estar ejecutándose'}
 if(Test-Path $journal){throw 'Ya existe un diario; restaure antes de repetir.'}
 $rows=@()
 foreach($nic in Get-NetAdapter -Physical | Where-Object Status -eq 'Up'){
  foreach($family in @(@{Name='IPv4';Node='Tcpip';Loop='127.0.0.1'},@{Name='IPv6';Node='Tcpip6';Loop='::1'})){
   $path="HKLM:\SYSTEM\CurrentControlSet\Services\$($family.Node)\Parameters\Interfaces\$(([guid]$nic.InterfaceGuid).ToString('B'))"
   $static=(Get-ItemProperty -LiteralPath $path -Name NameServer -ErrorAction SilentlyContinue).NameServer
   $rows+= [pscustomobject]@{Guid=$nic.InterfaceGuid.ToString();Family=$family.Name;Static=$static;Loop=$family.Loop;Done=$false}
  }
 }
 if(!$rows.Count){throw 'No se encontraron adaptadores físicos activos'}
 if(@($rows | Where-Object {![string]::IsNullOrWhiteSpace($_.Static)}).Count){throw 'Esta versión sólo activa adaptadores con DNS automático en ambas familias. Se rechaza DNS estático para no arriesgar una restauración parcial.'}
 Save-Journal $rows
 try{
  foreach($row in $rows){
   $nic=Get-NetAdapter | Where-Object {$_.InterfaceGuid.ToString() -eq $row.Guid}
   Get-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -AddressFamily $row.Family | Set-DnsClientServerAddress -ServerAddresses @($row.Loop)
  }
  Clear-DnsClientCache
 }catch{Write-Error "Aplicación incompleta. Ejecute Restore; diario conservado. $_"}
}else{
 if(!(Test-Path $journal)){Write-Host 'Sin cambios de red registrados';exit 0}
 $rows=Get-Content -LiteralPath $journal -Raw | ConvertFrom-Json
 foreach($row in $rows){
  if($row.Done){continue}
  $nic=Get-NetAdapter -IncludeHidden | Where-Object {$_.InterfaceGuid.ToString() -eq $row.Guid}
  if(!$nic){throw "Adaptador ausente $($row.Guid); se conserva el diario para recuperar al reconectarlo."}
  $dns=Get-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -AddressFamily $row.Family
  if(($dns.ServerAddresses -join ',') -eq $row.Loop){
   if([string]::IsNullOrWhiteSpace($row.Static)){$dns | Set-DnsClientServerAddress -ResetServerAddresses}
   else{$dns | Set-DnsClientServerAddress -ServerAddresses @($row.Static -split '[,;\s]+' | Where-Object {$_})}
   $verified=Get-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -AddressFamily $row.Family
   if(($verified.ServerAddresses -join ',') -eq $row.Loop){throw "Restauración no aplicada en $($row.Guid)/$($row.Family). Se conserva el diario y el servicio debe continuar activo."}
  }else{Write-Warning "DNS modificado externamente en $($row.Guid)/$($row.Family); no se sobrescribe."}
  $row.Done=$true;Save-Journal $rows
 }
 Clear-DnsClientCache
 Move-Item -LiteralPath $journal -Destination "$journal.restored" -Force
}
