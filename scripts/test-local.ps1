param([Parameter(Mandatory)][string]$Data)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
if(Test-Path $Data){throw 'Use un directorio nuevo para no alterar un estado existente.'}
New-Item -ItemType Directory $Data | Out-Null
[IO.File]::WriteAllText("$Data/lock.json",'null')
[IO.File]::WriteAllText("$Data/owner.txt",[Security.Principal.WindowsIdentity]::GetCurrent().User.Value)
Copy-Item "$root/config/rules.json" "$Data/rules.json"
$exe=Join-Path $root 'dist/Service/Sentinel.Service.exe'
function Start-Demo {
 Start-Process -FilePath $exe -ArgumentList @('--console','--data',('"'+$Data+'"')) -PassThru -WindowStyle Hidden -RedirectStandardOutput "$Data/stdout.log" -RedirectStandardError "$Data/stderr.log"
}
function Control([byte]$Command){
 $pipe=[IO.Pipes.NamedPipeClientStream]::new('.','Sentinel.Demo',[IO.Pipes.PipeDirection]::InOut,[IO.Pipes.PipeOptions]::Asynchronous)
 $timeout=[Threading.CancellationTokenSource]::new(5000)
 try {
  $pipe.ConnectAsync($timeout.Token).GetAwaiter().GetResult()
  $pipe.WriteByte($Command)
  $reader=[IO.StreamReader]::new($pipe)
  $reader.ReadToEndAsync($timeout.Token).GetAwaiter().GetResult() | ConvertFrom-Json
 } finally {$pipe.Dispose();$timeout.Dispose()}
}
$process=$null
try{
 $process=Start-Demo
 $status=Control 0
 if($status.Service -ne 'EN EJECUCIÓN'){throw 'Estado inicial incorrecto'}
 'PASS pipe y arranque de demo'
 python "$root/scripts/dns-smoke.py"
 if($LASTEXITCODE){throw 'Falló DNS smoke'}
 $request=Control 1
 if($request.Ready -or $request.Remaining -gt 86400 -or $request.Remaining -lt 86390){throw 'Espera inicial incorrecta'}
 Start-Sleep -Seconds 3
 $before=Control 0
 if($before.Remaining -ge $request.Remaining -or $before.Ready){throw 'El contador no avanza correctamente'}
 'PASS solicitud y avance sin desbloqueo temprano'
 Stop-Process -Id $process.Id -Force
 $process.WaitForExit()
 $process=Start-Demo
 $after=Control 0
 if($after.Ready -or $after.Remaining -gt $before.Remaining+2 -or $after.Remaining -lt $before.Remaining-5){throw 'Persistencia incorrecta tras reiniciar el proceso'}
 'PASS persistencia tras reiniciar proceso (no reinicio de Windows)'
 $cancel=Control 2
 if($null -ne $cancel.Remaining -or $cancel.Ready){throw 'Cancelación incorrecta'}
 'PASS cancelación de solicitud'
 $process.Refresh()
 [pscustomobject]@{WorkingSetBytes=$process.WorkingSet64;CpuSeconds=$process.TotalProcessorTime.TotalSeconds;Scope='Muestra puntual, no benchmark'} | ConvertTo-Json -Compress
}finally{
 if($process -and !$process.HasExited){Stop-Process -Id $process.Id -Force;$process.WaitForExit()}
 if(Test-Path "$Data/stderr.log"){Get-Content "$Data/stderr.log"}
}
