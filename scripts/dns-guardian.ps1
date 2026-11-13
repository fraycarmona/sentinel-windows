param([switch]$Once)
$ErrorActionPreference='Stop'
function Test-SentinelDns {
 $udp=[Net.Sockets.UdpClient]::new()
 try{
  $id=Get-Random -Minimum 1 -Maximum 65535
  # Fixed benign probe also checks that the upstream provider remains reachable.
  [byte[]]$q=@(($id -shr 8),($id -band 255),1,0,0,1,0,0,0,0,0,0,7,101,120,97,109,112,108,101,3,99,111,109,0,0,1,0,1)
  $udp.Connect('127.0.0.1',53);$null=$udp.Send($q,$q.Length)
  $receive=$udp.ReceiveAsync();if(!$receive.Wait(2000)){return $false}
  $b=$receive.Result.Buffer
  return ($b.Length -ge 12 -and $b[0] -eq $q[0] -and $b[1] -eq $q[1] -and ($b[2] -band 128) -ne 0 -and ($b[3] -band 15) -eq 0 -and ($b[6] -gt 0 -or $b[7] -gt 0))
 }catch{return $false}finally{$udp.Dispose()}
}
$data=Join-Path $env:ProgramData 'Sentinel'
$failures=0
# The service needs time to start after Windows boots.
if(!$Once){Start-Sleep -Seconds 30}
do{
 try{
  $dns=@(Get-DnsClientServerAddress | Where-Object {$_.ServerAddresses -contains '127.0.0.1' -or $_.ServerAddresses -contains '::1'})
  if($dns.Count -and (Test-Path (Join-Path $data 'network-backup.json'))){
   $service=Get-Service Sentinel -ErrorAction SilentlyContinue
   if(!$service -or $service.Status -ne 'Running' -or !(Test-SentinelDns)){$failures++}else{$failures=0}
   if($failures -ge 2 -or $Once){
    if($failures -gt 0){
     & "$PSScriptRoot/network-lab.ps1" -Restore -Emergency -AcceptLabChanges
     [IO.File]::WriteAllText((Join-Path $data 'guardian-status.txt'),"$(Get-Date -Format o): DNS anterior restaurado por fallo del motor. Requiere reactivación explícita.")
     $failures=0
    }
   }
  }else{$failures=0}
 }catch{
  try{[IO.File]::WriteAllText((Join-Path $data 'guardian-status.txt'),"$(Get-Date -Format o): recuperación pendiente: $($_.Exception.Message)")}catch{}
 }
 if(!$Once){Start-Sleep -Seconds 10}
}while(!$Once)
