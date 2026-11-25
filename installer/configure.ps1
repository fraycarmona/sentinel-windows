#Requires -RunAsAdministrator
param([Parameter(Mandatory)][ValidateSet('Install','Remove')][string]$Operation)
$ErrorActionPreference='Stop'

$target=Join-Path $env:ProgramFiles 'Sentinel'
$data=Join-Path $env:ProgramData 'Sentinel'
$ownerMarker=Join-Path $data 'setup-owned'
$guardian='SentinelDnsRecovery'
$serviceKey='HKLM:\SYSTEM\CurrentControlSet\Services\Sentinel'

function Assert-PackagedService {
    $image=(Get-ItemProperty -LiteralPath $serviceKey).ImagePath
    $servicePath=Join-Path $target 'Service\Sentinel.Service.exe'
    if($image -ine ('"'+$servicePath+'"') -and $image -ine $servicePath){
        throw 'El servicio no pertenece a este instalador.'
    }
}

function Test-PackagedData {
    if(!(Test-Path -LiteralPath $data -PathType Container)){return $false}
    $directory=Get-Item -LiteralPath $data -Force
    if($directory.Attributes -band [IO.FileAttributes]::ReparsePoint){return $false}
    $acl=$directory.GetAccessControl()
    if(!$acl.AreAccessRulesProtected -or
        $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value -notin 'S-1-5-18','S-1-5-32-544'){
        return $false
    }
    return Test-Path -LiteralPath $ownerMarker -PathType Leaf
}

function Write-SetupError([string]$Message) {
    Write-Host $Message
    if(Test-PackagedData){
        [IO.File]::WriteAllText((Join-Path $data 'setup-error.txt'),$Message)
    }
}

if($Operation -eq 'Install'){
    if((Test-Path -LiteralPath $data) -or (Test-Path -LiteralPath $serviceKey) -or
        (Get-ScheduledTask -TaskName $guardian -ErrorAction SilentlyContinue)){
        Write-Host 'Existe un servicio, una tarea o un estado previo de SENTINEL.'
        exit 1
    }
    try{
        & "$PSScriptRoot/install-lab.ps1" -Packaged -AcceptLabChanges
        Import-Module "$PSScriptRoot/DnsHealth.psm1" -Force
        $healthy=$false
        foreach($attempt in 1..5){
            if((Test-SentinelFilteredResolver) -and (Test-SentinelFilteredResolver '::1')){
                $healthy=$true
                break
            }
            Start-Sleep -Seconds 1
        }
        if(!$healthy){throw 'El motor no superó el sondeo de filtrado IPv4/IPv6.'}

        & "$PSScriptRoot/hosts-lab.ps1" -Mode Apply
        & "$PSScriptRoot/strict-lab.ps1" -Mode Apply -AcceptLabChanges
        & "$PSScriptRoot/network-lab.ps1" -Apply -AcceptLabChanges
        Resolve-DnsName example.com -Type A -DnsOnly -NoHostsFile -QuickTimeout | Out-Null
        & "$PSScriptRoot/register-guardian.ps1" -Packaged
        exit 0
    }catch{
        $message=$_.Exception.Message
        if(Test-PackagedData){
            try{
                if(Test-Path -LiteralPath $serviceKey){Assert-PackagedService}
                & "$PSScriptRoot/remove-lab.ps1" -Emergency -AcceptLabChanges
                if((Test-Path -LiteralPath $serviceKey) -or
                    (Get-ScheduledTask -TaskName $guardian -ErrorAction SilentlyContinue)){
                    throw 'El servicio o la tarea siguen registrados.'
                }
            }catch{
                $message+=". Restauración pendiente: $($_.Exception.Message)"
            }
        }
        Write-SetupError $message
        exit 1
    }
}

try{
    $ownsData=Test-PackagedData
    if(!$ownsData -and ((Test-Path -LiteralPath $data) -or (Test-Path -LiteralPath $serviceKey))){
        throw 'El estado instalado no pertenece al paquete.'
    }
    if(Test-Path -LiteralPath $serviceKey){
        Assert-PackagedService
        Import-Module "$PSScriptRoot/StrictControl.psm1" -Force
        try{Assert-SentinelRemovalReady}catch{Write-Host $_.Exception.Message;exit 24}
        & "$PSScriptRoot/remove-lab.ps1" -AcceptLabChanges
    }
    foreach($journal in 'hosts-backup.json','strict-backup.json','network-backup.json','browser-backup.json'){
        if(Test-Path -LiteralPath (Join-Path $data $journal)){throw "Pendiente de restaurar: $journal"}
    }
    if((Test-Path -LiteralPath $serviceKey) -or
        (Get-ScheduledTask -TaskName $guardian -ErrorAction SilentlyContinue)){
        throw 'El servicio o la tarea siguen registrados.'
    }
    if($ownsData){Remove-Item -LiteralPath $data -Recurse -Force}
    $ui=Join-Path $target 'UI\SENTINEL.exe'
    Get-Process SENTINEL -ErrorAction SilentlyContinue | Where-Object Path -eq $ui | Stop-Process
    exit 0
}catch{
    Write-SetupError $_.Exception.Message
    exit 1
}
