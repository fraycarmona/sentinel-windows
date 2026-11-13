#Requires -RunAsAdministrator
param([Parameter(Mandatory)][string]$PreviousBootUtc)
$ErrorActionPreference='Stop'
Import-Module "$PSScriptRoot/DnsHealth.psm1" -Force
$boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime()
if($boot -le [datetime]::Parse($PreviousBootUtc).ToUniversalTime()){throw 'Windows aún no ha arrancado de nuevo: no se declara probado el reinicio.'}
$service=Get-CimInstance Win32_Service -Filter "Name='Sentinel'"
if($service.StartMode -ne 'Auto' -or $service.State -ne 'Running'){throw 'Servicio no iniciado automáticamente.'}
$receipt=Get-Content (Join-Path $env:ProgramData 'Sentinel/boot-verification.json') -Raw | ConvertFrom-Json
if([datetime]::Parse($receipt.BootUtc).ToUniversalTime() -ne $boot -or !$receipt.FilteredProbe -or $receipt.GuardianIdentity -ne 'S-1-5-18'){throw 'No hay comprobación válida del guardián para este arranque.'}
if(!(Test-SentinelFilteredResolver)){throw 'No pasa el sondeo de filtro tras arrancar.'}
$run=(Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name Sentinel).Sentinel
if($run -ne ('"'+$env:ProgramFiles+'\Sentinel\UI\SENTINEL.exe"')){throw 'Panel no registrado para iniciar sesión.'}
[pscustomobject]@{BootUtc=$boot.ToString('o');Service='Running / Auto';Guardian='SYSTEM, sondeo correcto en este arranque';Dns='Filtro comprobado';UIStartupRegistered=$true;Scope='Comprobar también la ventana visible tras iniciar sesión; registro no prueba apertura de la interfaz.'}
