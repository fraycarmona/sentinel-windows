Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Get-SentinelBrowserPolicies {
 $rows=@()
 foreach($browser in 'Edge','Chrome'){
  $path=if($browser -eq 'Edge'){'SOFTWARE\Policies\Microsoft\Edge'}else{'SOFTWARE\Policies\Google\Chrome'}
  $private=if($browser -eq 'Edge'){'InPrivateModeAvailability'}else{'IncognitoModeAvailability'}
  foreach($entry in @(@('DnsOverHttpsMode','off','String'),@('ProxySettings','{"ProxyMode":"direct"}','String'),@($private,1,'DWord'),@('BrowserGuestModeEnabled',0,'DWord'),@('ForceGoogleSafeSearch',1,'DWord'),@('ForceYouTubeRestrict',2,'DWord'))){
   $rows += [pscustomobject]@{Kind='Registry';Path=$path;Name=$entry[0];Value=$entry[1];Type=$entry[2]}
  }
 }
 $rows += [pscustomobject]@{Kind='Registry';Path='SOFTWARE\Policies\Microsoft\Edge';Name='ForceBingSafeSearch';Value=2;Type='DWord'}
 $base='SOFTWARE\Policies\Mozilla\Firefox'
 foreach($entry in @(@('DNSOverHTTPS','Enabled',0,'DWord'),@('DNSOverHTTPS','Locked',1,'DWord'),@('Proxy','Mode','none','String'),@('Proxy','Locked',1,'DWord'),@('','DisablePrivateBrowsing',1,'DWord'))){
  $path=if($entry[0]){$base+'\'+$entry[0]}else{$base}
  $rows += [pscustomobject]@{Kind='Registry';Path=$path;Name=$entry[1];Value=$entry[2];Type=$entry[3]}
 }
 return $rows
}

function Get-SentinelNetworkRules {
 # Known public resolver endpoints only; this is not a universal DoH/VPN block.
 $known='1.0.0.1,1.1.1.1,8.8.4.4,8.8.8.8,9.9.9.9,149.112.112.112,2001:4860:4860::8844,2001:4860:4860::8888,2606:4700:4700::1001,2606:4700:4700::1111'
 foreach($protocol in 'TCP','UDP'){
  foreach($scope in 'KnownResolver','EncryptedDns'){
   [pscustomobject]@{Kind='NetworkFirewall';Name=('Sentinel.Network.'+$scope+'.'+$protocol);Program='Any';Group='SENTINEL Strict';Direction='Outbound';Action='Block';Enabled='True';Profile='Any';Protocol=$protocol;LocalPort='Any';RemotePort=$(if($scope -eq 'KnownResolver'){'53,443'}else{'853'});LocalAddress='Any';RemoteAddress=$(if($scope -eq 'KnownResolver'){$known}else{'Any'})}
  }
 }
}

function New-SentinelStrictPlan {
 param([string[]]$BlockedPrograms=@())
 $rows=@(Get-SentinelBrowserPolicies)+@(Get-SentinelNetworkRules)
 $seen=@{}
 foreach($program in $BlockedPrograms){
  if($program -notmatch '^[A-Za-z]:\\' -or $program -match '[*?%"\r\n]' -or [IO.Path]::GetExtension($program) -ine '.exe'){throw 'Indique rutas locales absolutas a ejecutables, sin variables ni comodines.'}
  $full=[IO.Path]::GetFullPath($program)
  if(!(Test-Path -LiteralPath $full -PathType Leaf)){throw "No existe el ejecutable: $full"}
  if($full.StartsWith($env:WINDIR+'\',[StringComparison]::OrdinalIgnoreCase) -or $full -match '(?i)\\Sentinel(\\|\.exe$)'){throw 'No se bloquean Windows ni SENTINEL.'}
  if($seen.ContainsKey($full)){continue};$seen[$full]=$true
  # Each rule has a unique, journaled identity. No global firewall defaults are changed.
  $rows += [pscustomobject]@{Kind='Firewall';Name=('Sentinel.Strict.'+[guid]::NewGuid().ToString('N'));Program=$full;Group='SENTINEL Strict';Direction='Outbound';Action='Block';Enabled='True';Profile='Any';Protocol='Any';LocalPort='Any';RemotePort='Any';LocalAddress='Any';RemoteAddress='Any'}
 }
 return $rows
}

function Assert-SentinelRemovalStatus {
 param($Status)
 if($null -eq $Status -or !($Status.PSObject.Properties.Name -contains 'Ready') -or $Status.Ready -isnot [bool] -or !$Status.Ready){throw 'Solicite la retirada y complete las 24 horas de servicio activo.'}
}

function Assert-SentinelRemovalReady {
 # Bound both connect and response. A stalled or malformed service never permits removal.
 $pipe=[IO.Pipes.NamedPipeClientStream]::new('.','Sentinel.Control',[IO.Pipes.PipeDirection]::InOut,[IO.Pipes.PipeOptions]::Asynchronous)
 $reader=$null
 try{
  $pipe.Connect(3000);
  if(-not ('Sentinel.Core.PipeIdentity' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'PipeIdentity.cs')}
  [Sentinel.Core.PipeIdentity]::AssertService($pipe)
  $pipe.WriteByte(0);$reader=[IO.StreamReader]::new($pipe)
  $task=$reader.ReadToEndAsync()
  if(!$task.Wait(3000)){throw 'El servicio no respondió a tiempo; retirada denegada.'}
  Assert-SentinelRemovalStatus ($task.Result | ConvertFrom-Json)
 }finally{if($reader){$reader.Dispose()};$pipe.Dispose()}
}

function Save-SentinelJournal {
 param([string]$Path,$Rows)
 $json=ConvertTo-Json -InputObject @($Rows) -Depth 8
 $temp=$Path+'.tmp'
 $bytes=[Text.UTF8Encoding]::new($false).GetBytes($json)
 $stream=[IO.File]::Open($temp,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
 if(Test-Path -LiteralPath $Path){for($attempt=0;;$attempt++){try{[IO.File]::Replace($temp,$Path,[NullString]::Value);break}catch [IO.IOException]{if($attempt -ge 6){throw};Start-Sleep -Milliseconds 60}}}else{[IO.File]::Move($temp,$Path)}
}

function Test-SentinelValueEqual {
 param($Actual,$Expected)
 if($null -eq $Actual){return $false}
 foreach($property in $Expected.PSObject.Properties){
  if($property.Name -eq 'State'){continue}
  if(!($Actual.PSObject.Properties.Name -contains $property.Name)){return $false}
  if($property.Name -in @('RemotePort','RemoteAddress')){
   if((@(([string]$Actual.($property.Name)) -split ',' | Sort-Object) -join ',') -cne (@(([string]$property.Value) -split ',' | Sort-Object) -join ',')){return $false}
  }elseif([string]$Actual.($property.Name) -cne [string]$property.Value){return $false}
 }
 return $true
}

function Assert-SentinelJournalRows {
 param($Rows)
 if(@($Rows).Count -eq 0){throw 'Diario vacío; recuperación manual necesaria.'}
 $catalog=@(Get-SentinelBrowserPolicies)
 $ids=@{}
 foreach($r in $Rows){
  if(($r.PSObject.Properties.Name -contains 'State') -and $r.State -notin @('Planned','Applying','Applied','Restored')){throw 'Estado de diario desconocido.'}
  if($r.Kind -eq 'Registry'){
   $match=@($catalog | Where-Object {$_.Path -ceq $r.Path -and $_.Name -ceq $r.Name})
   if($match.Count -ne 1 -or !(Test-SentinelValueEqual $r $match[0])){throw 'Política de diario desconocida o alterada.'}
   $id=$r.Path+'/'+$r.Name
  }elseif($r.Kind -eq 'NetworkFirewall'){
   $match=@(Get-SentinelNetworkRules | Where-Object Name -ceq $r.Name)
   if($match.Count -ne 1 -or !(Test-SentinelValueEqual $r $match[0])){throw 'Regla de red desconocida o alterada.'}
   $id=$r.Name
  }elseif($r.Kind -eq 'Firewall'){
   if($r.Name -notmatch '^Sentinel\.Strict\.[0-9a-f]{32}$' -or $r.Program -notmatch '^[A-Za-z]:\\' -or $r.Program -match '[*?%"\r\n]' -or [IO.Path]::GetExtension($r.Program) -ine '.exe' -or $r.Group -cne 'SENTINEL Strict' -or $r.Direction -cne 'Outbound' -or $r.Action -cne 'Block' -or $r.Enabled -cne 'True' -or $r.Profile -cne 'Any' -or $r.Protocol -cne 'Any' -or $r.LocalPort -cne 'Any' -or $r.RemotePort -cne 'Any' -or $r.LocalAddress -cne 'Any' -or $r.RemoteAddress -cne 'Any'){throw 'Regla de diario desconocida o alterada.'}
   $id=$r.Name
  }else{throw 'Tipo de diario desconocido.'}
  if($ids.ContainsKey($id)){throw 'Diario con entradas duplicadas.'};$ids[$id]=$true
 }
}

function Undo-SentinelStrictPlan {
 param([string]$Journal,[hashtable]$Backend)
 if(!(Test-Path -LiteralPath $Journal)){return}
 $rows=Get-Content -LiteralPath $Journal -Raw | ConvertFrom-Json
 Assert-SentinelJournalRows $rows
 # Validate every entry before deleting any. Conflicts remain journaled for recovery.
 foreach($r in $rows){
  if(!($r.PSObject.Properties.Name -contains 'State')){throw 'Diario sin estado de propiedad.'}
  if($r.State -in @('Planned','Restored')){continue}
  $actual=& $Backend.Read $r;if($null -ne $actual -and !(Test-SentinelValueEqual $actual $r)){throw 'Hay un cambio ajeno. Se conserva el diario y no se elimina esa configuración.'}
 }
 foreach($r in $rows){
  if($r.State -in @('Planned','Restored')){continue}
  $actual=& $Backend.Read $r
  if($null -eq $actual){continue}
  if(!(Test-SentinelValueEqual $actual $r)){throw 'Conflicto durante la restauración; diario conservado.'}
  & $Backend.Delete $r
  if($null -ne (& $Backend.Read $r)){throw 'Restauración incompleta; diario conservado.'}
  $r.State='Restored';Save-SentinelJournal $Journal $rows
 }
 # Retrying after a partial restore is safe: already absent entries are accepted.
 Remove-Item -LiteralPath $Journal -ErrorAction Stop
}

function Invoke-SentinelStrictPlan {
 param($Rows,[string]$Journal,[hashtable]$Backend)
 Assert-SentinelJournalRows $Rows
 if(Test-Path -LiteralPath $Journal){throw 'Ya existe un diario; no se sobrescribe.'}
 foreach($r in $Rows){if($null -ne (& $Backend.Read $r)){throw 'Existe una política o regla previa; no se sobrescribe.'}}
 $Rows=ConvertFrom-Json (ConvertTo-Json -InputObject @($Rows) -Depth 8)
 foreach($r in $Rows){$r | Add-Member -NotePropertyName State -NotePropertyValue Planned -Force}
 Save-SentinelJournal $Journal $Rows
 try{
  foreach($r in $Rows){
   if($null -ne (& $Backend.Read $r)){throw 'Apareció una configuración durante la aplicación.'}
   $r.State='Applying';Save-SentinelJournal $Journal $Rows
   & $Backend.Write $r
   if(!(Test-SentinelValueEqual (& $Backend.Read $r) $r)){throw 'La lectura posterior no coincide.'}
   $r.State='Applied';Save-SentinelJournal $Journal $Rows
  }
 }catch{
  $cause=$_.Exception.Message
  try{Undo-SentinelStrictPlan $Journal $Backend}catch{throw "$cause; rollback pendiente: $($_.Exception.Message)"}
  throw "$cause; cambios propios restaurados."
 }
}

function New-SentinelWindowsBackend {
 # Explicit 64-bit registry view even from a 32-bit host.
 return @{
  Read={param($r)
   if($r.Kind -eq 'Registry'){
    $hive=[Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine','Registry64');$key=$null
    try{$key=$hive.OpenSubKey($r.Path);if(!$key -or !($key.GetValueNames() -contains $r.Name)){return $null}
     [pscustomobject]@{Kind='Registry';Path=$r.Path;Name=$r.Name;Value=$key.GetValue($r.Name);Type=$key.GetValueKind($r.Name).ToString()}
    }finally{if($key){$key.Dispose()};$hive.Dispose()}
   }else{
    $rule=Get-NetFirewallRule -PolicyStore PersistentStore -Name $r.Name -ErrorAction SilentlyContinue
    if(!$rule){return $null}
    $app=$rule | Get-NetFirewallApplicationFilter
    $ports=$rule | Get-NetFirewallPortFilter
    $addresses=$rule | Get-NetFirewallAddressFilter
    [pscustomobject]@{Kind=$r.Kind;Name=$rule.Name;Program=$app.Program;Group=$rule.Group;Direction=$rule.Direction.ToString();Action=$rule.Action.ToString();Enabled=$rule.Enabled.ToString();Profile=$rule.Profile.ToString();Protocol=[string]$ports.Protocol;LocalPort=($ports.LocalPort -join ',');RemotePort=($ports.RemotePort -join ',');LocalAddress=($addresses.LocalAddress -join ',');RemoteAddress=($addresses.RemoteAddress -join ',')}
   }
  }
  Write={param($r)
   if($r.Kind -eq 'Registry'){
    $hive=[Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine','Registry64');$key=$null
    try{$key=$hive.CreateSubKey($r.Path);$key.SetValue($r.Name,$r.Value,[Enum]::Parse([Microsoft.Win32.RegistryValueKind],$r.Type))}finally{if($key){$key.Dispose()};$hive.Dispose()}
   }else{New-NetFirewallRule -PolicyStore PersistentStore -Name $r.Name -DisplayName 'SENTINEL: aplicación restringida' -Group $r.Group -Direction Outbound -Action Block -Program $r.Program -Profile Any -Enabled True -Protocol $r.Protocol -RemotePort @($r.RemotePort -split ',') -RemoteAddress @($r.RemoteAddress -split ',') | Out-Null
    if(!(Get-NetFirewallRule -PolicyStore ActiveStore -Name $r.Name -ErrorAction SilentlyContinue)){throw 'La regla no aparece en la política efectiva del firewall.'}
   }
  }
  Delete={param($r)
   if($r.Kind -eq 'Registry'){
    $hive=[Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine','Registry64');$key=$null
    try{$key=$hive.OpenSubKey($r.Path,$true);if($key){$key.DeleteValue($r.Name,$false)}}finally{if($key){$key.Dispose()};$hive.Dispose()}
   }else{Remove-NetFirewallRule -PolicyStore PersistentStore -Name $r.Name -ErrorAction Stop}
  }
 }
}

Export-ModuleMember -Function Get-SentinelNetworkRules,Get-SentinelBrowserPolicies,New-SentinelStrictPlan,Assert-SentinelRemovalStatus,Assert-SentinelRemovalReady,Test-SentinelValueEqual,Assert-SentinelJournalRows,Invoke-SentinelStrictPlan,Undo-SentinelStrictPlan,New-SentinelWindowsBackend
