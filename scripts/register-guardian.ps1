#Requires -RunAsAdministrator
$ErrorActionPreference='Stop'
$script=Join-Path $env:ProgramFiles 'Sentinel/scripts/dns-guardian.ps1'
if(!(Test-Path -LiteralPath $script)){throw 'Falta el componente de recuperación instalado.'}
$arguments='-NoProfile -NonInteractive -File "'+$script+'"'
$previous=Get-ScheduledTask -TaskName SentinelDnsRecovery -ErrorAction SilentlyContinue
if($previous -and @($previous.Actions | Where-Object {$_.Arguments -ne $arguments}).Count){throw 'Existe una tarea de recuperación ajena; no se modifica.'}
$action=New-ScheduledTaskAction -Execute "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument $arguments
$trigger=New-ScheduledTaskTrigger -AtStartup
$settings=New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName SentinelDnsRecovery -Action $action -Trigger $trigger -Settings $settings -User SYSTEM -RunLevel Highest -Description 'Reinicia el motor, comprueba DNS filtrado y concilia adaptadores al arrancar. Respaldo filtrado si falla el motor.' -Force | Out-Null
Start-ScheduledTask -TaskName SentinelDnsRecovery
