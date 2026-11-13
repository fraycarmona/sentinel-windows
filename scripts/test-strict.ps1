param([Parameter(Mandatory)][string]$Scratch)
$ErrorActionPreference='Stop'
Import-Module "$PSScriptRoot/StrictControl.psm1" -Force
if(Test-Path -LiteralPath $Scratch){throw 'Use un directorio de pruebas nuevo.'}
New-Item -ItemType Directory -Path $Scratch | Out-Null
$script:passed=0
function Check($Value){if(!$Value){throw 'Comprobación fallida'}}
function Reject([scriptblock]$Action){$rejected=$false;try{& $Action | Out-Null}catch{$rejected=$true};Check $rejected}
function Test($Name,[scriptblock]$Action){& $Action;$script:passed++;Write-Host "PASS $Name"}
function Fixture {
 $state=@{Values=@{};Writes=0;Deletes=0;FailAt=0;FailAfter=$false;ReadMismatch=$false;DeleteFails=$false}
 $backend=@{
  Read={param($r)$id=$(if($r.Kind -eq 'Registry'){$r.Path+'/'+$r.Name}else{$r.Name});$value=$state.Values[$id];if($state.ReadMismatch -and $null -ne $value){return [pscustomobject]@{Kind='Invalid'}};return $value}.GetNewClosure()
  Write={param($r)
   $state.Writes++
   if($state.FailAt -eq $state.Writes -and !$state.FailAfter){throw 'Fallo antes de escribir'}
   $state.Values[$(if($r.Kind -eq 'Registry'){$r.Path+'/'+$r.Name}else{$r.Name})]=ConvertFrom-Json (ConvertTo-Json $r)
   if($state.FailAt -eq $state.Writes){throw 'Fallo tras escribir'}
  }.GetNewClosure()
  Delete={param($r)if($state.DeleteFails){throw 'Fallo de retirada'};$state.Deletes++;$state.Values.Remove($(if($r.Kind -eq 'Registry'){$r.Path+'/'+$r.Name}else{$r.Name}))}.GetNewClosure()
 }
 return @{State=$state;Backend=$backend;Journal=(Join-Path $Scratch ([guid]::NewGuid().ToString()+'.json'));Rows=@(Get-SentinelBrowserPolicies)}
}
Test '18 políticas: incógnito, invitado, proxy directo y DNS del sistema' {
 $r=@(Get-SentinelBrowserPolicies);Check ($r.Count -eq 18)
 Check (@($r | Where-Object {$_.Name -in @('InPrivateModeAvailability','IncognitoModeAvailability','DisablePrivateBrowsing') -and $_.Value -eq 1}).Count -eq 3)
}
Test 'Plan sin efectos de sistema' {Check (@(New-SentinelStrictPlan).Count -eq 22)}
Test 'Retirada denegada antes de 24 h o con respuesta inválida' {
 foreach($s in @($null,[pscustomobject]@{},[pscustomobject]@{Ready=$false},[pscustomobject]@{Ready='true'})){Reject {Assert-SentinelRemovalStatus $s}}
 Assert-SentinelRemovalStatus ([pscustomobject]@{Ready=$true})
}
Test 'Aplicar, comprobar y restaurar todas las políticas' {
 $f=Fixture;Invoke-SentinelStrictPlan $f.Rows $f.Journal $f.Backend
 Check ($f.State.Values.Count -eq 18);Check (Test-Path $f.Journal)
 Undo-SentinelStrictPlan $f.Journal $f.Backend
 Check ($f.State.Values.Count -eq 0);Check (!(Test-Path $f.Journal))
 Undo-SentinelStrictPlan $f.Journal $f.Backend
}
Test 'Política previa: cero escrituras y sin diario' {
 $f=Fixture;$f.State.Values['SOFTWARE\Policies\Microsoft\Edge/DnsOverHttpsMode']=[pscustomobject]@{Value='secure'}
 Reject {Invoke-SentinelStrictPlan $f.Rows $f.Journal $f.Backend}
 Check ($f.State.Writes -eq 0);Check (!(Test-Path $f.Journal))
}
Test 'Fallo parcial antes de escribir: rollback' {
 $f=Fixture;$f.State.FailAt=3
 Reject {Invoke-SentinelStrictPlan $f.Rows $f.Journal $f.Backend}
 Check ($f.State.Values.Count -eq 0);Check (!(Test-Path $f.Journal))
}
Test 'Fallo parcial después de escribir: rollback' {
 $f=Fixture;$f.State.FailAt=3;$f.State.FailAfter=$true
 Reject {Invoke-SentinelStrictPlan $f.Rows $f.Journal $f.Backend}
 Check ($f.State.Values.Count -eq 0);Check (!(Test-Path $f.Journal))
}
Test 'Conflicto ajeno conserva diario y configuración' {
 $f=Fixture;Invoke-SentinelStrictPlan $f.Rows $f.Journal $f.Backend
 $f.State.Values['SOFTWARE\Policies\Microsoft\Edge/InPrivateModeAvailability'].Value=0
 Reject {Undo-SentinelStrictPlan $f.Journal $f.Backend}
 Check ($f.State.Deletes -eq 0);Check (Test-Path $f.Journal)
}
Test 'Fallo de rollback conserva diario para reintentar' {
 $f=Fixture;$f.State.FailAt=3;$f.State.DeleteFails=$true
 Reject {Invoke-SentinelStrictPlan $f.Rows $f.Journal $f.Backend}
 Check (Test-Path $f.Journal);$f.State.DeleteFails=$false
 Undo-SentinelStrictPlan $f.Journal $f.Backend;Check ($f.State.Values.Count -eq 0)
}
Test 'Restauración tras interrupción: entradas ya ausentes' {
 $f=Fixture;Invoke-SentinelStrictPlan $f.Rows $f.Journal $f.Backend
 $f.State.Values.Remove('SOFTWARE\Policies\Microsoft\Edge/InPrivateModeAvailability')
 Undo-SentinelStrictPlan $f.Journal $f.Backend;Check ($f.State.Values.Count -eq 0)
}
Test 'Diario alterado no permite eliminar claves arbitrarias' {
 $f=Fixture;Invoke-SentinelStrictPlan $f.Rows $f.Journal $f.Backend
 $rows=Get-Content $f.Journal -Raw | ConvertFrom-Json;$rows[0].Path='SOFTWARE\Other'
 ConvertTo-Json -InputObject @($rows) -Depth 8 | Set-Content $f.Journal
 Reject {Undo-SentinelStrictPlan $f.Journal $f.Backend};Check ($f.State.Deletes -eq 0)
}
Test 'Lectura incorrecta no se declara aplicada' {
 $f=Fixture;$f.State.ReadMismatch=$true
 Reject {Invoke-SentinelStrictPlan $f.Rows $f.Journal $f.Backend};Check (Test-Path $f.Journal)
}
Test 'Regla por ejecutable: ruta exacta y sin duplicados' {
 $exe=Join-Path (Resolve-Path $Scratch).Path 'dummy.exe';[IO.File]::WriteAllText($exe,'test fixture - not executable')
 $p=@(New-SentinelStrictPlan -BlockedPrograms @($exe,$exe));Check ($p.Count -eq 23)
 Check ($p[-1].Direction -eq 'Outbound' -and $p[-1].Action -eq 'Block' -and $p[-1].Program -eq $exe)
 $f=Fixture;Invoke-SentinelStrictPlan $p $f.Journal $f.Backend;Undo-SentinelStrictPlan $f.Journal $f.Backend
}
Test 'Recuperación no elimina una entrada prevista pero nunca aplicada' {
 $f=Fixture;Invoke-SentinelStrictPlan $f.Rows $f.Journal $f.Backend
 $rows=Get-Content $f.Journal -Raw | ConvertFrom-Json
 $rows[0].State='Planned'
 ConvertTo-Json -InputObject @($rows) -Depth 8 | Set-Content $f.Journal
 Undo-SentinelStrictPlan $f.Journal $f.Backend
 Check ($f.State.Values.Count -eq 1)
}
Test 'Regla de firewall modificada conserva configuración y diario' {
 $exe=Join-Path (Resolve-Path $Scratch).Path 'dummy.exe'
 $p=@(New-SentinelStrictPlan -BlockedPrograms @($exe));$f=Fixture
 Invoke-SentinelStrictPlan $p $f.Journal $f.Backend
 $f.State.Values[$p[-1].Name].RemotePort='443'
 Reject {Undo-SentinelStrictPlan $f.Journal $f.Backend}
 Check ($f.State.Deletes -eq 0);Check (Test-Path $f.Journal)
}
Test 'Rechaza rutas relativas, UNC, comodines y ejecutables inexistentes' {
 foreach($p in @('browser.exe','\\server\browser.exe','C:\*.exe','C:\missing-sentinel-test.exe')){Reject {New-SentinelStrictPlan -BlockedPrograms $p}}
}
Test 'Reglas de red acotadas y diario modificado rechazado' {
 $p=@(New-SentinelStrictPlan);$f=Fixture
 Check (@($p | Where-Object Kind -eq NetworkFirewall).Count -eq 4)
 Invoke-SentinelStrictPlan $p $f.Journal $f.Backend
 $rows=Get-Content $f.Journal -Raw | ConvertFrom-Json
 ($rows | Where-Object Kind -eq NetworkFirewall | Select-Object -First 1).RemoteAddress='Any'
 ConvertTo-Json -InputObject @($rows) -Depth 8 | Set-Content $f.Journal
 Reject {Undo-SentinelStrictPlan $f.Journal $f.Backend};Check ($f.State.Deletes -eq 0)
}
Write-Host "$script:passed pruebas de modo estricto superadas. Backend simulado: no se cambió registro ni firewall."
