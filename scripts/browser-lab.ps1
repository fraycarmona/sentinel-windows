#Requires -RunAsAdministrator
param([switch]$Apply,[switch]$Restore,[switch]$Emergency,[Parameter(Mandatory)][switch]$AcceptLabChanges)
$ErrorActionPreference='Stop'
if($Restore -and !$Emergency){Import-Module "$PSScriptRoot/StrictControl.psm1" -Force;Assert-SentinelRemovalReady}
if(!$AcceptLabChanges -or ($Apply -eq $Restore)){throw 'Seleccione Apply o Restore y confirme AcceptLabChanges.'}
$journal=Join-Path $env:ProgramData 'Sentinel/browser-backup.json'
if($Apply){
 if(Test-Path $journal){throw 'Ya existe un diario de políticas.'}
 $rows=@()
 foreach($path in 'SOFTWARE\Policies\Microsoft\Edge','SOFTWARE\Policies\Google\Chrome'){
  foreach($entry in @(@('DnsOverHttpsMode','off','String'),@('ForceGoogleSafeSearch',1,'DWord'),@('ForceYouTubeRestrict',2,'DWord'))){
   $rows += [pscustomobject]@{Path=$path;Name=$entry[0];Value=$entry[1];Kind=$entry[2];Done=$false}
  }
 }
 $rows += [pscustomobject]@{Path='SOFTWARE\Policies\Mozilla\Firefox\DNSOverHTTPS';Name='Enabled';Value=0;Kind='DWord';Done=$false}
 $rows += [pscustomobject]@{Path='SOFTWARE\Policies\Mozilla\Firefox\DNSOverHTTPS';Name='Locked';Value=1;Kind='DWord';Done=$false}
 # Do not overwrite organizational or existing policies. Preflight every value first.
 foreach($row in $rows){$key=[Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($row.Path);try{if($key -and $key.GetValueNames().Contains($row.Name)){throw "Existe una política previa: $($row.Path)/$($row.Name)"}}finally{if($key){$key.Dispose()}}}
 [IO.File]::WriteAllText($journal,(ConvertTo-Json -InputObject $rows -Depth 5))
 foreach($row in $rows){$key=[Microsoft.Win32.Registry]::LocalMachine.CreateSubKey($row.Path);try{$key.SetValue($row.Name,$row.Value,[Enum]::Parse([Microsoft.Win32.RegistryValueKind],$row.Kind))}finally{$key.Dispose()}}
}else{
 if(!(Test-Path $journal)){exit 0}
 $rows=Get-Content $journal -Raw | ConvertFrom-Json
 foreach($row in $rows){
  $key=[Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($row.Path,$true)
  try{if($key -and ($key.GetValue($row.Name) -eq $row.Value)){$key.DeleteValue($row.Name,$false)}}finally{if($key){$key.Dispose()}}
 }
 Move-Item -LiteralPath $journal -Destination "$journal.restored" -Force
}
Write-Host 'Reinicie los navegadores y verifique edge://policy, chrome://policy y about:policies. No se presupone que una política escrita esté aplicada.'
