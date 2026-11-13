param([Parameter(Mandatory)][string]$Data)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
if(Test-Path $Data){throw 'Use un directorio nuevo.'}
New-Item -ItemType Directory $Data | Out-Null
[IO.File]::WriteAllText("$Data/lock.json",'null')
[IO.File]::WriteAllText("$Data/owner.txt",[Security.Principal.WindowsIdentity]::GetCurrent().User.Value)
Copy-Item "$root/config/rules.json" "$Data/rules.json"
$p=Start-Process "$root/dist/Service/Sentinel.Service.exe" -ArgumentList @('--console','--data',('"'+$Data+'"')) -WindowStyle Hidden -PassThru -RedirectStandardOutput "$Data/out.log" -RedirectStandardError "$Data/error.log"
$pipe=$null
try{
 $pipe=[IO.Pipes.NamedPipeClientStream]::new('.','Sentinel.Demo',[IO.Pipes.PipeDirection]::InOut)
 $pipe.Connect(5000);$pipe.WriteByte(0)
 $reader=[IO.StreamReader]::new($pipe);$null=$reader.ReadToEnd()
 [byte[]]$q=@(1,2,1,0,0,1,0,0,0,0,0,0,7,98,108,111,99,107,101,100,4,116,101,115,116,0,0,1,0,1)
 foreach($i in 1..300){$u=[Net.Sockets.UdpClient]::new();try{$null=$u.Send($q,$q.Length,'127.0.0.1',1053)}finally{$u.Dispose()};Start-Sleep -Milliseconds 5}
 Start-Sleep -Seconds 1
 $p.Refresh();if($p.HasExited){throw 'El proceso cayó al recibir ICMP de clientes desconectados.'}
 $u=[Net.Sockets.UdpClient]::new()
 try{$u.Connect('127.0.0.1',1053);$null=$u.Send($q,$q.Length);$t=$u.ReceiveAsync();if(!$t.Wait(3000) -or ($t.Result.Buffer[3] -band 15) -ne 3){throw 'El resolvedor no responde después de la prueba.'}}finally{$u.Dispose()}
 'PASS 300 clientes desconectados; proceso vivo y DNS responde después.'
}finally{
 if($pipe){$pipe.Dispose()}
 if(!$p.HasExited){Stop-Process -Id $p.Id -Force;$p.WaitForExit()}
}
