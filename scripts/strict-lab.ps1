param([ValidateSet('Plan','Apply','Restore','Status')][string]$Mode='Plan',[string[]]$BlockedPrograms=@(),[switch]$Emergency,[switch]$AcceptLabChanges)
$ErrorActionPreference='Stop'
if(![Environment]::Is64BitProcess){throw 'Ejecute PowerShell de 64 bits.'}
Import-Module "$PSScriptRoot/StrictControl.psm1" -Force
if($Mode -eq 'Plan'){
 New-SentinelStrictPlan -BlockedPrograms $BlockedPrograms | ConvertTo-Json -Depth 8
 return
}
$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
if(!([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Este modo requiere un proceso administrativo.'}
$data=Join-Path $env:ProgramData 'Sentinel'
$journal=Join-Path $data 'strict-backup.json'
# Serialize mutation and status operations. File lives in the protected installation directory.
$lease=[IO.File]::Open((Join-Path $data 'strict-operation.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try{
 $backend=New-SentinelWindowsBackend
 if($Mode -eq 'Status'){
  if(!(Test-Path -LiteralPath $journal)){'Modo estricto: NO CONFIGURADO';return}
  $rows=Get-Content -LiteralPath $journal -Raw | ConvertFrom-Json
  Assert-SentinelJournalRows $rows
  foreach($r in $rows){[pscustomobject]@{Kind=$r.Kind;Name=$r.Name;ConfigurationMatches=(Test-SentinelValueEqual (& $backend.Read $r) $r)}}
  'Coincidir con el registro o firewall NO acredita política efectiva ni bloqueo real del navegador.'
  return
 }
 if(!$AcceptLabChanges){throw 'Se requiere -AcceptLabChanges para modificar el sistema.'}
 if($Mode -eq 'Restore'){
  if(!$Emergency){Assert-SentinelRemovalReady}
  Undo-SentinelStrictPlan $journal $backend
  'Cambios del modo estricto retirados.';return
 }
 if($Emergency){throw 'Emergency sólo sirve para recuperación.'}
 if((Get-Service Sentinel -ErrorAction Stop).Status -ne 'Running'){throw 'El servicio DNS debe estar en ejecución.'}
 if(Test-Path (Join-Path $data 'browser-backup.json')){throw 'Existen políticas de laboratorio previas; no se mezclan diarios.'}
 # A pre-existing InPrivate allowlist overrides the Edge disable policy.
 if(Test-Path 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\InPrivateModeUrlAllowlist'){throw 'Existe una excepción InPrivate previa; requiere revisión.'}
 if(@($BlockedPrograms).Count){
  $profiles=@(Get-NetFirewallProfile -PolicyStore ActiveStore)
  if($profiles.Count -ne 3 -or @($profiles | Where-Object {$_.Enabled -ne 'True' -or $_.AllowLocalFirewallRules -eq 'False'}).Count){throw 'Firewall desactivado o políticas locales no admitidas; no se cambia su configuración global.'}
 }
 $rows=@(New-SentinelStrictPlan -BlockedPrograms $BlockedPrograms)
 Invoke-SentinelStrictPlan $rows $journal $backend
 'Configuración aplicada. Reinicie navegadores y compruebe las políticas y el tráfico antes de declarar cobertura.'
}finally{$lease.Dispose()}
