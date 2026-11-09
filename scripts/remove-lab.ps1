#Requires -RunAsAdministrator
param([switch]$Emergency,[Parameter(Mandatory)][switch]$AcceptLabChanges)
$ErrorActionPreference='Stop'
if(!$AcceptLabChanges){throw 'Confirmación requerida'}
if(!$Emergency){
 $pipe=[IO.Pipes.NamedPipeClientStream]::new('.','Sentinel.Control',[IO.Pipes.PipeDirection]::InOut)
 try{$pipe.Connect(3000);$pipe.WriteByte(0);$reader=[IO.StreamReader]::new($pipe);$status=$reader.ReadToEnd() | ConvertFrom-Json;if(!$status.Ready){throw 'Solicite la retirada en la interfaz y complete la espera.'}}finally{$pipe.Dispose()}
}
# Restore BEFORE stopping the resolver. Errors leave service available for recovery.
& "$PSScriptRoot/network-lab.ps1" -Restore -AcceptLabChanges
& "$PSScriptRoot/browser-lab.ps1" -Restore -AcceptLabChanges
if(Get-Service Sentinel -ErrorAction SilentlyContinue){Stop-Service Sentinel; & sc.exe delete Sentinel;if($LASTEXITCODE){throw 'No se pudo retirar el servicio'}}
$target=Join-Path $env:ProgramFiles 'Sentinel'
$run='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
if((Get-ItemProperty $run -Name Sentinel -ErrorAction SilentlyContinue).Sentinel -eq ('"'+$target+'\UI\SENTINEL.exe"')){Remove-ItemProperty $run -Name Sentinel}
$uninstall='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Sentinel'
if((Get-ItemProperty $uninstall -Name UninstallString -ErrorAction SilentlyContinue).UninstallString -eq ('"'+$target+'\UI\SENTINEL.exe" --uninstall')){Remove-Item -LiteralPath $uninstall}
Write-Host 'Servicio retirado; copia y estado conservados para diagnóstico. Puede eliminar Program Files\Sentinel y ProgramData\Sentinel tras verificar la conectividad.'
