Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Save-SentinelNetworkJournal {
 param([string]$Path,$Rows)
 $bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject @($Rows) -Depth 8))
 $tmp=$Path+'.tmp';$s=[IO.File]::Open($tmp,'Create','Write','None')
 try{$s.Write($bytes,0,$bytes.Length);$s.Flush($true)}finally{$s.Dispose()}
 if(Test-Path -LiteralPath $Path){for($attempt=0;;$attempt++){try{[IO.File]::Replace($tmp,$Path,[NullString]::Value);break}catch [IO.IOException]{if($attempt -ge 6){throw};Start-Sleep -Milliseconds 60}}}else{[IO.File]::Move($tmp,$Path)}
}
function Get-SentinelFallback($Family){
 if($Family -eq 'IPv4'){return @('1.1.1.3','1.0.0.3')}
 if($Family -eq 'IPv6'){return @('2606:4700:4700::1113','2606:4700:4700::1003')}
 throw 'Familia desconocida.'
}
function Set-SentinelNetworkMode {
 param([ValidateSet('Local','Fallback','Restore')][string]$Mode,[string]$Journal,[hashtable]$Backend)
 if(!(Test-Path -LiteralPath $Journal)){throw 'No hay diario de red.'}
 $rows=Get-Content -LiteralPath $Journal -Raw | ConvertFrom-Json
 foreach($r in $rows){
  $null=[guid]::Parse($r.Guid)
  if($r.Family -notin @('IPv4','IPv6') -or $r.Loop -cne $(if($r.Family -eq 'IPv4'){'127.0.0.1'}else{'::1'}) -or ![string]::IsNullOrWhiteSpace($r.Static)){throw 'Diario de red no compatible; no se modifica.'}
 }
 foreach($r in $rows){
  if($r.Done){continue}
  $current=& $Backend.Read $r
  if($null -eq $current){if($Mode -eq 'Restore'){throw 'Adaptador ausente; diario conservado.'};continue}
  $fallback=@(Get-SentinelFallback $r.Family)
  $owned=($current.Addresses -join ',') -eq $r.Loop -or ($current.Addresses -join ',') -eq ($fallback -join ',')
  # DHCP is acceptable only before the very first write, or after an interrupted reset.
  $automatic=[string]::IsNullOrWhiteSpace($current.Static)
  if(!$owned -and !$automatic){throw 'DNS ajeno detectado; no se sobrescribe. Protección degradada.'}
  if($Mode -eq 'Restore'){
   if($owned){& $Backend.Reset $r}
   $after=& $Backend.Read $r
   if($null -eq $after -or ![string]::IsNullOrWhiteSpace($after.Static)){throw 'DNS automático no restaurado; se conserva diario.'}
   $r.Done=$true;Save-SentinelNetworkJournal $Journal $rows
  }else{
   $desired=if($Mode -eq 'Local'){@($r.Loop)}else{$fallback}
   if(($current.Addresses -join ',') -ne ($desired -join ',')){& $Backend.Write $r $desired}
   $after=& $Backend.Read $r
   if($null -eq $after -or ($after.Addresses -join ',') -ne ($desired -join ',')){throw 'No coincide el DNS aplicado.'}
  }
 }
 if($Mode -eq 'Restore'){Move-Item -LiteralPath $Journal -Destination ($Journal+'.restored') -Force}
}
function New-SentinelNetworkBackend {
 return @{
  Read={param($r)
   $nic=Get-NetAdapter -IncludeHidden | Where-Object {$_.InterfaceGuid.ToString() -eq $r.Guid}
   if(!$nic){return $null}
   $node=if($r.Family -eq 'IPv4'){'Tcpip'}else{'Tcpip6'}
   $path="HKLM:\SYSTEM\CurrentControlSet\Services\$node\Parameters\Interfaces\$(([guid]$r.Guid).ToString('B'))"
   $value=Get-ItemProperty -LiteralPath $path -ErrorAction SilentlyContinue
   $static=if($value -and $value.PSObject.Properties['NameServer']){$value.NameServer}else{''}
   [pscustomobject]@{Addresses=@((Get-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -AddressFamily $r.Family).ServerAddresses);Static=$static}
  }
  Write={param($r,$addresses)
   $nic=Get-NetAdapter -IncludeHidden | Where-Object {$_.InterfaceGuid.ToString() -eq $r.Guid}
   Get-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -AddressFamily $r.Family | Set-DnsClientServerAddress -ServerAddresses $addresses
  }
  Reset={param($r)
   $nic=Get-NetAdapter -IncludeHidden | Where-Object {$_.InterfaceGuid.ToString() -eq $r.Guid}
   Get-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -AddressFamily $r.Family | Set-DnsClientServerAddress -ResetServerAddresses
  }
 }
}
Export-ModuleMember -Function Save-SentinelNetworkJournal,Get-SentinelFallback,Set-SentinelNetworkMode,New-SentinelNetworkBackend
