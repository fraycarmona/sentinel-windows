param([switch]$Once)
$ErrorActionPreference='Stop'
Import-Module "$PSScriptRoot/DnsHealth.psm1" -Force
Import-Module "$PSScriptRoot/StrictControl.psm1" -Force
$data=Join-Path $env:ProgramData 'Sentinel'
$failures=0;$lastReceipt=[datetime]::MinValue
$boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o')
if(!$Once){Start-Sleep -Seconds 30}
do{
 $lease=$null
 try{
  try{$lease=[IO.File]::Open((Join-Path $data 'maintenance.lock'),'OpenOrCreate','ReadWrite','None')}catch{if($Once){throw};Start-Sleep -Seconds 10;continue}
  if(!(Test-Path (Join-Path $data 'network-backup.json'))){if($Once){break};Start-Sleep -Seconds 10;continue}
  $service=Get-Service Sentinel -ErrorAction Stop
  if($service.Status -eq 'Stopped'){
   try{Start-Service Sentinel;(Get-Service Sentinel).WaitForStatus('Running',[TimeSpan]::FromSeconds(10))}catch{}
  }
  $healthy=Test-SentinelFilteredResolver
  $mode='LOCAL'
  if($healthy){
   $failures=0
   & "$PSScriptRoot/network-lab.ps1" -Reconcile -AcceptLabChanges
  }else{
   $failures++
   if($failures -ge 2 -or $Once){
    & "$PSScriptRoot/network-lab.ps1" -Fallback -AcceptLabChanges
    $mode='RESPALDO FILTRADO: categorías; hosts residual; SafeSearch DNS local no disponible'
   }else{$mode='FALLO DNS: pendiente de segundo sondeo'}
  }
  $policies=0
  $journal=Join-Path $data 'strict-backup.json'
  if(Test-Path $journal){
   $rows=Get-Content $journal -Raw | ConvertFrom-Json;Assert-SentinelJournalRows $rows;$backend=New-SentinelWindowsBackend
   foreach($row in $rows){
    if($row.State -ne 'Applied'){throw 'Política incompleta; necesita revisión.'}
    $actual=& $backend.Read $row
    if($null -eq $actual){& $backend.Write $row;$actual=& $backend.Read $row}
    if(!(Test-SentinelValueEqual $actual $row)){throw 'Conflicto en políticas: protección parcial; no se sobrescribe configuración ajena.'}
    $policies++
   }
  }
  [IO.File]::WriteAllText((Join-Path $data 'guardian-status.txt'),"$(Get-Date -Format o): $mode; $policies controles coinciden.")
  if($Once -or ((Get-Date)-$lastReceipt).TotalSeconds -ge 60){
   $receipt=[pscustomobject]@{BootUtc=$boot;CheckedUtc=[datetime]::UtcNow.ToString('o');Service=(Get-Service Sentinel).Status.ToString();FilteredProbe=$healthy;Mode=$mode;Policies=$policies;GuardianIdentity=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;Dns=@(Get-DnsClientServerAddress | Where-Object {$_.ServerAddresses.Count} | Select-Object InterfaceAlias,AddressFamily,ServerAddresses)}
   [IO.File]::WriteAllText((Join-Path $data 'boot-verification.json'),($receipt | ConvertTo-Json -Depth 6))
   $lastReceipt=Get-Date
  }
 }catch{
  try{[IO.File]::WriteAllText((Join-Path $data 'guardian-status.txt'),"$(Get-Date -Format o): protección degradada: $($_.Exception.Message)")}catch{}
 }finally{if($lease){$lease.Dispose()}}
 if(!$Once){Start-Sleep -Seconds 15}
}while(!$Once)
