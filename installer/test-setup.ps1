#Requires -RunAsAdministrator
param([Parameter(Mandatory)][string]$Setup)
$ErrorActionPreference='Stop'
$os=Get-CimInstance Win32_OperatingSystem
if($os.ProductType -ne 1 -or [int]$os.BuildNumber -lt 22000){
    throw "La prueba requiere una VM cliente Windows 11; se encontró $($os.Caption)."
}
Write-Host "$($os.Caption), compilación $($os.BuildNumber), $env:PROCESSOR_ARCHITECTURE"

$temp=if($env:RUNNER_TEMP){$env:RUNNER_TEMP}else{[IO.Path]::GetTempPath()}
$evidence=Join-Path $temp 'sentinel-test'
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
$app=Join-Path $env:ProgramFiles 'Sentinel'
$data=Join-Path $env:ProgramData 'Sentinel'
$hostsFile=Join-Path $env:WINDIR 'System32\drivers\etc\hosts'
$arp='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\SentinelSetup'
$uninstaller=Join-Path $app 'unins000.exe'
$guardian='SentinelDnsRecovery'
if((Test-Path $app) -or (Test-Path $data) -or (Test-Path $arp) -or
    (Get-Service Sentinel -ErrorAction SilentlyContinue) -or
    (Get-ScheduledTask -TaskName $guardian -ErrorAction SilentlyContinue)){
    throw 'La VM debe empezar sin SENTINEL.'
}

function Invoke-Package([string]$Executable,[string]$LogName) {
    $log=Join-Path $evidence "$LogName.log"
    $process=Start-Process -FilePath $Executable -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',"/LOG=""$log""" -Wait -PassThru
    return $process.ExitCode
}

function Get-AdapterDns {
    $adapters=@(Get-NetAdapter -Physical | Where-Object Status -eq 'Up')
    $clients=@(Get-DnsClientServerAddress | Where-Object InterfaceIndex -in $adapters.ifIndex)
    if(!$clients.Count){throw 'La VM no tiene adaptadores físicos activos con cliente DNS.'}
    foreach($row in $clients | Sort-Object InterfaceIndex,AddressFamily){
        "$($row.InterfaceIndex):$($row.AddressFamily):$($row.ServerAddresses -join ',')"
    }
}

function Read-SentinelStatus {
    param([byte]$Command=0)
    $pipe=[IO.Pipes.NamedPipeClientStream]::new('.','Sentinel.Control',[IO.Pipes.PipeDirection]::InOut,[IO.Pipes.PipeOptions]::Asynchronous)
    try{
        $pipe.Connect(5000)
        [Sentinel.Core.PipeIdentity]::AssertService($pipe)
        $pipe.WriteByte($Command)
        $reader=[IO.StreamReader]::new($pipe)
        try{
            $task=$reader.ReadToEndAsync()
            if(!$task.Wait(5000)){throw 'El canal del servicio no respondió.'}
            return $task.Result | ConvertFrom-Json
        }finally{$reader.Dispose()}
    }finally{$pipe.Dispose()}
}

Get-NetAdapter | Format-Table Name,InterfaceDescription,ifIndex,HardwareInterface,Status
Get-DnsClientServerAddress | Format-Table InterfaceAlias,InterfaceIndex,AddressFamily
$originalDns=@(Get-AdapterDns) -join [Environment]::NewLine
$hostsHash=(Get-FileHash $hostsFile).Hash
$panel=$null
try{
    $setupCode=Invoke-Package $Setup 'setup'
    if($setupCode -ne 0){
        Get-Content (Join-Path $evidence 'setup.log') -Tail 30 | Write-Host
        throw "El instalador devolvió $setupCode."
    }

    $service=Get-CimInstance Win32_Service -Filter "Name='Sentinel'"
    if($service.StartMode -ne 'Auto' -or $service.State -ne 'Running' -or
        $service.StartName -notmatch 'LocalService$' -or
        $service.PathName -ine ('"'+(Join-Path $app 'Service\Sentinel.Service.exe')+'"')){
        throw 'Servicio SCM incorrecto.'
    }
    $task=Get-ScheduledTask -TaskName $guardian
    if($task.Triggers.CimClass.CimClassName -ne 'MSFT_TaskBootTrigger' -or
        $task.Principal.UserId -notin 'SYSTEM','S-1-5-18','NT AUTHORITY\SYSTEM'){
        throw 'Arranque del guardián incorrecto.'
    }
    $startup=Join-Path ([Environment]::GetFolderPath('Startup')) 'SENTINEL.lnk'
    $shell=New-Object -ComObject WScript.Shell
    $ui=Join-Path $app 'UI\SENTINEL.exe'
    if(!(Test-Path $startup) -or $shell.CreateShortcut($startup).TargetPath -ne $ui){
        throw 'Falta el acceso directo de inicio del panel.'
    }
    if((Get-ItemProperty $arp).UninstallString -ne ('"'+$ui+'" --uninstall')){
        throw 'Aplicaciones instaladas no dirige la retirada al panel.'
    }

    Import-Module "$app\scripts\DnsHealth.psm1" -Force
    if(!(Test-SentinelFilteredResolver) -or !(Test-SentinelFilteredResolver '::1') -or
        @((Get-AdapterDns) | Where-Object {$_ -notmatch ':(127\.0\.0\.1|::1)$'}).Count){
        throw 'El filtrado efectivo IPv4/IPv6 no coincide con el esperado.'
    }
    if(!(Test-Path "$data\hosts-backup.json") -or !(Test-Path "$data\strict-backup.json")){
        throw 'Faltan los diarios de protección.'
    }
    $boot=Get-CimInstance Win32_OperatingSystem
    $receiptPath=Join-Path $data 'boot-verification.json'
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while(!(Test-Path $receiptPath) -and $timer.Elapsed.TotalSeconds -lt 90){Start-Sleep -Seconds 2}
    $receipt=Get-Content $receiptPath -Raw | ConvertFrom-Json
    if(!$receipt.FilteredProbe -or $receipt.GuardianIdentity -ne 'S-1-5-18' -or
        [datetime]::Parse($receipt.BootUtc).ToUniversalTime() -ne $boot.LastBootUpTime.ToUniversalTime()){
        throw 'El guardián no verificó el DNS durante esta sesión.'
    }

    Add-Type -Path "$app\scripts\PipeIdentity.cs"
    $initial=Read-SentinelStatus
    if($initial.Ready -ne $false -or $null -ne $initial.Remaining -or $initial.Error){
        throw 'El estado de retirada inicial es incorrecto.'
    }
    $panel=Start-Process -FilePath $ui -ArgumentList '--uninstall' -PassThru
    $timer.Restart()
    do{
        Start-Sleep -Milliseconds 500
        $panel.Refresh()
        if($panel.HasExited){throw "El panel instalado terminó con código $($panel.ExitCode)."}
        $requested=Read-SentinelStatus
    }until($null -ne $requested.Remaining -or $timer.Elapsed.TotalSeconds -ge 20)
    if($requested.Ready -ne $false -or $requested.Remaining -lt 86380 -or $requested.Remaining -gt 86400){
        throw 'La entrada de Aplicaciones instaladas no inicia la espera de 24 horas.'
    }
    $null=Invoke-Package $uninstaller 'retirada-anticipada'
    if(!(Test-Path $arp) -or !(Test-Path $uninstaller) -or
        (Get-Service Sentinel).Status -ne 'Running' -or (Read-SentinelStatus).Ready -ne $false -or
        !(Test-SentinelFilteredResolver)){
        throw 'Una retirada anticipada alteró la instalación.'
    }
    $cancelled=Read-SentinelStatus -Command 2
    if($cancelled.Ready -ne $false -or $null -ne $cancelled.Remaining){
        throw 'No se canceló la solicitud.'
    }
    Write-Host 'Activación, configuración de arranque y retirada anticipada verificadas.'
}catch{
    Write-Host "Error en la prueba de instalación: $($_.Exception.Message)"
    throw
}finally{
    if($panel -and !$panel.HasExited){Stop-Process -InputObject $panel}
    foreach($name in 'setup-error.txt','guardian-status.txt','runtime\service-error.txt'){
        $path=Join-Path $data $name
        if(Test-Path $path){Get-Content -Encoding UTF8 $path | Out-File (Join-Path $evidence "$([IO.Path]::GetFileNameWithoutExtension($name)).log")}
    }
    if((Test-Path "$data\setup-owned") -and (Test-Path "$app\scripts\remove-lab.ps1")){
        & "$app\scripts\remove-lab.ps1" -Emergency -AcceptLabChanges
    }
    if(Test-Path $uninstaller){
        $cleanup=Invoke-Package $uninstaller 'limpieza'
        if($cleanup -ne 0){throw "La limpieza del paquete devolvió $cleanup."}
    }
    if((Get-Service Sentinel -ErrorAction SilentlyContinue) -or
        (Get-ScheduledTask -TaskName $guardian -ErrorAction SilentlyContinue) -or
        (Test-Path $arp) -or (Test-Path $data) -or
        ((@(Get-AdapterDns) -join [Environment]::NewLine) -ne $originalDns) -or
        ((Get-FileHash $hostsFile).Hash -ne $hostsHash)){
        throw 'El estado inicial de la VM no quedó restaurado.'
    }
    Write-Host 'Restauración de DNS, hosts y registro del paquete verificada.'
}
