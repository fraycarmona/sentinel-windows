#Requires -RunAsAdministrator
param([Parameter(Mandatory)][string]$Evidence,[switch]$BrowserTest)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
$target=Join-Path $env:ProgramFiles 'Sentinel'
$data=Join-Path $env:ProgramData 'Sentinel'
if((Test-Path $target) -or (Test-Path $data) -or (Get-Service Sentinel -ErrorAction SilentlyContinue)){throw 'Instalación existente: prueba cancelada sin cambios.'}
New-Item -ItemType Directory -Force $Evidence | Out-Null
$result=[ordered]@{Success=$false;Cleanup=$false;Checks=@();Error=$null}
$watchdog=$null
Start-Transcript -Path "$Evidence/admin-transcript.txt" -Force | Out-Null
function Check([bool]$Ok,[string]$Name){if(!$Ok){throw $Name};$result.Checks+=$Name;Write-Host "PASS $Name"}
function Control([byte]$Command){
 $pipe=[IO.Pipes.NamedPipeClientStream]::new('.','Sentinel.Control',[IO.Pipes.PipeDirection]::InOut)
 try{$pipe.Connect(5000);$pipe.WriteByte($Command);$reader=[IO.StreamReader]::new($pipe);$reader.ReadToEnd() | ConvertFrom-Json}finally{$pipe.Dispose()}
}
try{
 $listeners=@(Get-NetTCPConnection -State Listen -LocalPort 53 -ErrorAction SilentlyContinue)+@(Get-NetUDPEndpoint -LocalPort 53 -ErrorAction SilentlyContinue)
 Check (@($listeners | Where-Object {$_}).Count -eq 0) 'Puerto 53 disponible'
 $before=@(Get-DnsClientServerAddress | Select-Object InterfaceIndex,AddressFamily,ServerAddresses)
 $before | ConvertTo-Json -Depth 5 | Set-Content "$Evidence/dns-before.json"
 & "$PSScriptRoot/install-lab.ps1" -AcceptLabChanges
 $service=Get-Service Sentinel
 $service.WaitForStatus('Running',[TimeSpan]::FromSeconds(10))
 $service.Dispose()
 $status=Control 0
 Check ($status.Service -eq 'EN EJECUCIÓN') 'Servicio instalado y canal de control disponible'
 $account=(Get-CimInstance Win32_Service -Filter "Name='Sentinel'").StartName
 Check ($account -eq 'NT AUTHORITY\LocalService') 'Servicio bajo LocalService'
 # Verify the resolver before touching adapter DNS.
 $answer=Resolve-DnsName example.com -Server 127.0.0.1 -DnsOnly -Type A -QuickTimeout
 Check ([bool]($answer | Where-Object IPAddress)) 'Resolvedor de servicio responde antes de cambiar DNS'
 $request=Control 1
 Check (!$request.Ready -and $request.Remaining -gt 86390) 'Solicitud no desbloquea anticipadamente'
 Restart-Service Sentinel
 $status=Control 0
 Check (!$status.Ready -and $status.Remaining -gt 86380) 'Espera persistente tras reiniciar servicio'
 $status=Control 2
 Check ($null -eq $status.Remaining) 'Cancelación mediante servicio'
 # Independent recovery process: if this harness exits unexpectedly, DNS is restored.
 $recovery=Join-Path $Evidence 'watchdog.ps1'
 @'
param([string]$Scripts,[string]$Evidence)
for($i=0;$i -lt 180;$i++){Start-Sleep -Seconds 1}
if(Test-Path "$Evidence/armed") {
 try { & "$Scripts/network-lab.ps1" -Restore -AcceptLabChanges; 'restored' | Set-Content "$Evidence/watchdog-result.txt" }
 catch { $_ | Out-String | Set-Content "$Evidence/watchdog-result.txt" }
}
'@ | Set-Content $recovery
 'armed' | Set-Content "$Evidence/armed"
 $watchdog=Start-Process powershell.exe -ArgumentList @('-NoProfile','-File',('"'+$recovery+'"'),'-Scripts',('"'+$PSScriptRoot+'"'),'-Evidence',('"'+$Evidence+'"')) -WindowStyle Hidden -PassThru
 & "$PSScriptRoot/network-lab.ps1" -Apply -AcceptLabChanges
 $answer=Resolve-DnsName example.com -DnsOnly -Type A -QuickTimeout
 Check ([bool]($answer | Where-Object IPAddress)) 'Resolución del sistema con DNS temporal de SENTINEL'
 if($BrowserTest){
  'ready' | Set-Content "$Evidence/browser-ready"
  for($i=0;$i -lt 120;$i++){if(Test-Path "$Evidence/browser-done"){break};Start-Sleep -Seconds 1}
 }
 & "$PSScriptRoot/network-lab.ps1" -Restore -AcceptLabChanges
 Remove-Item -LiteralPath "$Evidence/armed"
 $after=@(Get-DnsClientServerAddress | Select-Object InterfaceIndex,AddressFamily,ServerAddresses)
 $after | ConvertTo-Json -Depth 5 | Set-Content "$Evidence/dns-after.json"
 Check (($before | ConvertTo-Json -Depth 5 -Compress) -eq ($after | ConvertTo-Json -Depth 5 -Compress)) 'DNS del sistema restaurado exactamente'
 $result.Success=$true
}catch{$result.Error=$_.Exception.Message;Write-Host "FAIL $($result.Error)"}
finally{
 try {
  if(Test-Path $data){& "$PSScriptRoot/remove-lab.ps1" -Emergency -AcceptLabChanges}
  if(Test-Path "$Evidence/armed"){Remove-Item -LiteralPath "$Evidence/armed"}
  if($watchdog -and !$watchdog.HasExited){Stop-Process -Id $watchdog.Id -Force}
  # Preserve journals outside installation directories before cleanup.
  if(Test-Path $data){Copy-Item -LiteralPath $data -Destination "$Evidence/state-backup" -Recurse}
  Check (!(Get-Service Sentinel -ErrorAction SilentlyContinue)) 'Servicio retirado tras la prueba'
  foreach($path in @($target,$data)){
   $expected=if($path -eq $target){Join-Path $env:ProgramFiles 'Sentinel'}else{Join-Path $env:ProgramData 'Sentinel'}
   if([IO.Path]::GetFullPath($path) -ne [IO.Path]::GetFullPath($expected)){throw 'Ruta de limpieza inesperada'}
   if(Test-Path $path){Remove-Item -LiteralPath $path -Recurse -Force}
  }
  $result.Cleanup=$true
 }catch{$result.Error+="; Recuperación: $($_.Exception.Message)";Write-Host $result.Error}
 $result | ConvertTo-Json -Depth 5 | Set-Content "$Evidence/result.json"
 Stop-Transcript | Out-Null
}
