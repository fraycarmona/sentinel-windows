param([Parameter(Mandatory)][string]$Scratch)
$ErrorActionPreference='Stop'
Import-Module "$PSScriptRoot/HostsControl.psm1" -Force
Import-Module "$PSScriptRoot/NetworkControl.psm1" -Force
if(Test-Path -LiteralPath $Scratch){throw 'Use un directorio nuevo.'}
New-Item -ItemType Directory $Scratch | Out-Null
$script:passed=0
function Check($b){if(!$b){throw 'Comprobación fallida'}}
function Reject([scriptblock]$f){$failed=$false;try{& $f}catch{$failed=$true};Check $failed}
function Test($name,[scriptblock]$f){& $f;$script:passed++;"PASS $name"}
Test 'Hosts conserva bytes previos y cambios ajenos posteriores' {
 $p=Join-Path $Scratch 'hosts';$j=$p+'.json'
 [byte[]]$before=@(35,32,255,195,169,13,10,49,50,55,46,48,46,48,46,49,32,108,111,99,97,108,104,111,115,116)
 [IO.File]::WriteAllBytes($p,$before)
 Add-SentinelHosts $p $j @('x.com','twitter.com')
 Add-SentinelHosts $p $j @('x.com','twitter.com')
 [IO.File]::AppendAllText($p,'# foreign',[Text.Encoding]::ASCII)
 Remove-SentinelHosts $p $j
 Check ([Convert]::ToBase64String([IO.File]::ReadAllBytes($p)) -ceq [Convert]::ToBase64String([byte[]]($before+[Text.Encoding]::ASCII.GetBytes('# foreign'))))
 Remove-SentinelHosts $p $j
}
Test 'Hosts alterado conserva diario y no elimina cambios' {
 $p=Join-Path $Scratch 'hosts2';$j=$p+'.json';[IO.File]::WriteAllText($p,'original')
 Add-SentinelHosts $p $j @('x.com')
 [IO.File]::WriteAllText($p,([IO.File]::ReadAllText($p).Replace('0.0.0.0 x.com','1.2.3.4 x.com')))
 Reject {Remove-SentinelHosts $p $j};Check (Test-Path $j)
}
Test 'Inyección de línea hosts rechazada' {Reject {New-SentinelHostsBlock @("x.com`n1.2.3.4 other.com")}}
function Fixture {
 $guid=[guid]::NewGuid().ToString();$journal=Join-Path $Scratch ($guid+'.json')
 $row=[pscustomobject]@{Guid=$guid;Family='IPv4';Static='';Loop='127.0.0.1';Done=$false}
 Save-SentinelNetworkJournal $journal @($row)
 $state=@{Addresses=@('127.0.0.1');Static='127.0.0.1';Writes=0;Fail=$false;Missing=$false}
 $backend=@{
  Read={param($r)if($state.Missing){return $null};[pscustomobject]@{Addresses=$state.Addresses;Static=$state.Static}}.GetNewClosure()
  Write={param($r,$ips)$state.Writes++;if($state.Fail){throw 'write failure'};$state.Addresses=@($ips);$state.Static=$ips -join ','}.GetNewClosure()
  Reset={param($r)$state.Writes++;$state.Addresses=@('192.168.18.1');$state.Static=''}.GetNewClosure()
 }
 @{Journal=$journal;State=$state;Backend=$backend}
}
Test 'Local a respaldo filtrado, vuelta local y restauración DHCP' {
 $f=Fixture
 Set-SentinelNetworkMode Fallback $f.Journal $f.Backend
 Check (($f.State.Addresses -join ',') -eq '1.1.1.3,1.0.0.3')
 Set-SentinelNetworkMode Local $f.Journal $f.Backend
 Check (($f.State.Addresses -join ',') -eq '127.0.0.1')
 Set-SentinelNetworkMode Restore $f.Journal $f.Backend
 Check ($f.State.Static -eq '' -and !(Test-Path $f.Journal))
}
Test 'DNS externo estático no se sobrescribe' {
 $f=Fixture;$f.State.Addresses=@('8.8.8.8');$f.State.Static='8.8.8.8'
 Reject {Set-SentinelNetworkMode Local $f.Journal $f.Backend};Check ($f.State.Writes -eq 0)
 Reject {Set-SentinelNetworkMode Restore $f.Journal $f.Backend};Check (Test-Path $f.Journal)
}
Test 'Fallo conserva diario para reintento' {
 $f=Fixture;$f.State.Fail=$true;Reject {Set-SentinelNetworkMode Fallback $f.Journal $f.Backend}
 Check (Test-Path $f.Journal);$f.State.Fail=$false;Set-SentinelNetworkMode Fallback $f.Journal $f.Backend
}
Test 'Adaptador ausente no se declara restaurado' {
 $f=Fixture;$f.State.Missing=$true;Reject {Set-SentinelNetworkMode Restore $f.Journal $f.Backend};Check (Test-Path $f.Journal)
}
Test 'Diario manipulado no cambia DNS' {
 $f=Fixture;$rows=Get-Content $f.Journal -Raw | ConvertFrom-Json;$rows[0].Loop='8.8.8.8';Save-SentinelNetworkJournal $f.Journal $rows
 Reject {Set-SentinelNetworkMode Local $f.Journal $f.Backend};Check ($f.State.Writes -eq 0)
}
"$script:passed pruebas de recuperación superadas; archivos temporales y backend DNS simulado."
