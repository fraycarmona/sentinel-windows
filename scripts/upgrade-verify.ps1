#Requires -RunAsAdministrator
param([Parameter(Mandatory)][string]$Evidence,[switch]$VerifyOnly)
$ErrorActionPreference='Stop'
$data=Join-Path $env:ProgramData 'Sentinel'
New-Item -ItemType Directory $Evidence -Force | Out-Null
function Phase($text){[IO.File]::WriteAllText((Join-Path $Evidence 'stage.txt'),$text)}
function Pass($text){Add-Content -LiteralPath (Join-Path $Evidence 'tests.txt') -Value ('PASS '+$text) -Encoding UTF8}
function Check($value,$message){if(!$value){throw $message}}
function Test-BlockedHost([string]$Domain){
 try{
  $ips=@([Net.Dns]::GetHostAddresses($Domain) | ForEach-Object ToString)
  return ($ips.Count -gt 0 -and @($ips | Where-Object {$_ -notin @('0.0.0.0','::')}).Count -eq 0)
 }catch{
  $cause=$_.Exception
  while($cause.InnerException){$cause=$cause.InnerException}
  return ($cause -is [Net.Sockets.SocketException] -and $cause.SocketErrorCode -in @('HostNotFound','NoData'))
 }
}
function Status {
 if(-not ('Sentinel.Core.PipeIdentity' -as [type])){Add-Type -Path "$PSScriptRoot/PipeIdentity.cs"}
 $pipe=[IO.Pipes.NamedPipeClientStream]::new('.','Sentinel.Control',[IO.Pipes.PipeDirection]::InOut,[IO.Pipes.PipeOptions]::Asynchronous)
 try{
  $pipe.Connect(4000);[Sentinel.Core.PipeIdentity]::AssertService($pipe);$pipe.WriteByte(0)
  $reader=[IO.StreamReader]::new($pipe);$read=$reader.ReadToEndAsync()
  if(!$read.Wait(4000)){throw 'No responde IPC'}
  return ($read.Result | ConvertFrom-Json)
 }finally{$pipe.Dispose()}
}
$lease=$null
try{
 [IO.File]::WriteAllText((Join-Path $Evidence 'tests.txt'),'')
 Phase 'Comprobaciones previas'
 $boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o')
 [IO.File]::WriteAllText((Join-Path $Evidence 'previous-boot.txt'),$boot)
 Import-Module "$PSScriptRoot/Maintenance.psm1" -Force
 Import-Module "$PSScriptRoot/DnsHealth.psm1" -Force
 Import-Module "$PSScriptRoot/StrictControl.psm1" -Force
 $prior=Status
 Phase 'Actualizando servicio con respaldo filtrado'
 if(!$VerifyOnly){& "$PSScriptRoot/repair-service.ps1"}
 $lease=Enter-SentinelMaintenance
 Phase 'Aplicando hosts, políticas y controles de DNS conocidos'
 & "$PSScriptRoot/hosts-lab.ps1" -Mode Apply
 if(!(Test-Path "$data/strict-backup.json")){& "$PSScriptRoot/strict-lab.ps1" -Mode Apply -AcceptLabChanges}
 & "$PSScriptRoot/network-lab.ps1" -Apply -AcceptLabChanges
 $status=Status
 Check ($status.Version -eq '0.5.0' -and !$status.Demo) 'No responde el servicio actualizado.'
 if($null -eq $prior.Remaining){Check ($null -eq $status.Remaining -and !$status.Ready) 'La actualización alteró el estado de espera.'}
 else{Check ($null -ne $status.Remaining -and $status.Remaining -le $prior.Remaining) 'La actualización reinició la espera.'}
 Pass 'IPC autenticado y estado de espera preservado durante actualización'
 Check (Test-SentinelFilteredResolver) 'No funciona filtro local.'
 Check (Test-SentinelFilteredResolver '::1') 'No funciona filtro local IPv6.'
 Pass 'DNS local IPv4 e IPv6: dominio permitido y diagnóstico de categoría bloqueado'
 foreach($site in 'https://www.google.com','https://example.com'){
  Check ((Invoke-WebRequest $site -UseBasicParsing -TimeoutSec 20).StatusCode -eq 200) 'Falla sitio permitido.'
 }
 Pass 'Google y example.com accesibles por HTTPS'
 $deny=$false
 try{$null=Invoke-WebRequest 'https://dns.google/resolve?name=example.com&type=A' -UseBasicParsing -TimeoutSec 5}catch{$deny=$true}
 Check $deny 'DoH externo conocido todavía accesible.'
 Pass 'Endpoint conocido Google DoH inaccesible (DNS/hosts y reglas acotadas)'
 foreach($domain in 'x.com','stripchat.com'){
  Check (Test-BlockedHost $domain) 'Falla bloqueo residual/DNS.'
 }
 Pass 'Hosts residual para Twitter y dominio adulto configurado, sin abrir contenido'
 $backend=New-SentinelWindowsBackend;$rows=Get-Content "$data/strict-backup.json" -Raw | ConvertFrom-Json
 Check (@($rows).Count -eq 22) 'Faltan controles.'
 foreach($row in $rows){Check (Test-SentinelValueEqual (& $backend.Read $row) $row) 'Control no coincide.'}
 Pass '18 políticas y 4 reglas firewall leídas después de aplicar'
 $lease.Dispose();$lease=$null
 Phase 'Comprobando rechazo de parada anticipada'
 if(!$status.Ready){
  try{Stop-Service Sentinel -ErrorAction Stop}catch{}
  Check ((Get-Service Sentinel).Status -eq 'Running') 'Se permitió detener antes de la espera.'
  $denied=$false;try{Assert-SentinelRemovalReady}catch{$denied=$true};Check $denied 'Retirada anticipada permitida.'
  Pass 'Parada ordinaria y retirada anticipada rechazadas'
 }
 Phase 'Probando respaldo filtrado y recuperación del motor'
 $lease=Enter-SentinelMaintenance
 & "$PSScriptRoot/network-lab.ps1" -Fallback -AcceptLabChanges
 Stop-Service Sentinel -ErrorAction Stop
 Check ((Get-Service Sentinel).Status -eq 'Stopped') 'No se detuvo para prueba autorizada de recuperación.'
 Check (Test-SentinelFilteredResolver '1.1.1.3') 'Respaldo no filtra.'
 Check (Test-BlockedHost 'x.com') 'Hosts residual no bloquea con motor detenido.'
 Check ((Invoke-WebRequest 'https://example.com' -UseBasicParsing -TimeoutSec 15).StatusCode -eq 200) 'Sin conectividad de respaldo.'
 $lease.Dispose();$lease=$null
 & "$PSScriptRoot/dns-guardian.ps1" -Once
 Check ((Get-Service Sentinel).Status -eq 'Running') 'Guardián no reinició motor.'
 Check (Test-SentinelFilteredResolver) 'Motor recuperado no filtra.'
 $dns=@(Get-DnsClientServerAddress -InterfaceIndex (Get-NetAdapter -Physical | Where-Object Status -eq Up).ifIndex | ForEach-Object ServerAddresses)
 Check ($dns.Count -gt 0 -and @($dns | Where-Object {$_ -notin @('127.0.0.1','::1')}).Count -eq 0) 'DNS local no recuperado.'
 Pass 'Con motor parado: respaldo filtrado y conectividad; guardián vuelve a iniciar motor y DNS local'
 $rootAcl=(Get-Acl $data).Access
 Check (@($rootAcl | Where-Object {$_.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value -eq 'S-1-5-19'}).Count -eq 0) 'ACL todavía usa LocalService compartido.'
 Pass 'Configuración sin permisos compartidos LocalService; estado en runtime con SID propio'
 $svc=Get-CimInstance Win32_Service -Filter "Name='Sentinel'"
 Check ($svc.StartMode -eq 'Auto' -and $svc.StartName -eq 'NT AUTHORITY\LocalService') 'Configuración de arranque incorrecta.'
 $task=Get-ScheduledTask -TaskName SentinelDnsRecovery
 Check (@($task.Triggers | Where-Object {$_.CimClass.CimClassName -eq 'MSFT_TaskBootTrigger'}).Count -eq 1) 'No hay disparador de arranque.'
 Pass 'Servicio Automatic y tarea SYSTEM al arrancar configurados; reinicio de Windows pendiente'
 Status | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Evidence 'status.json') -Encoding UTF8
 [IO.File]::WriteAllText((Join-Path $Evidence 'result.txt'),'ACTIVO; pruebas de actualización superadas. Reinicio de Windows pendiente.')
 Phase 'ACTIVO; pendiente reinicio real'
}catch{
 $message=$_.Exception.ToString()+"`r`n"+$_.ScriptStackTrace
 [IO.File]::WriteAllText((Join-Path $Evidence 'result.txt'),$message)
 Phase 'FALLO: revisar result.txt; no declarar cobertura completa'
 exit 1
}finally{if($lease){$lease.Dispose()}}
