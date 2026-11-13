param([Parameter(Mandatory)][string]$Scratch)
$ErrorActionPreference='Stop'
if(Test-Path $Scratch){throw 'Use an empty scratch directory'}
New-Item -ItemType Directory -Path "$Scratch/Sentinel" -Force | Out-Null
$taskOriginalProgramData=$env:ProgramData
$script:calls=[Collections.Generic.List[string]]::new()
$script:restored=@{}
function Get-NetAdapter {param([switch]$IncludeHidden) [pscustomobject]@{InterfaceGuid='test-guid';ifIndex=99}}
function Get-DnsClientServerAddress {param($InterfaceIndex,$AddressFamily) [pscustomobject]@{Family=$AddressFamily;ServerAddresses=@($(if($script:restored.ContainsKey($AddressFamily)){$script:restored[$AddressFamily]}elseif($AddressFamily -eq 'IPv4'){'127.0.0.1'}else{'::1'}))}}
function Set-DnsClientServerAddress {
 param([Parameter(ValueFromPipeline=$true)]$InputObject,[switch]$ResetServerAddresses,[string[]]$ServerAddresses)
 process { $script:calls.Add("$($InputObject.Family):$ResetServerAddresses`:$($ServerAddresses -join ',')");$script:restored[$InputObject.Family]=$(if($ResetServerAddresses){'192.0.2.53'}else{$ServerAddresses}) }
}
function Clear-DnsClientCache { }
try {
 $env:ProgramData=$Scratch
 $rows=@([pscustomobject]@{Guid='test-guid';Family='IPv4';Static='';Loop='127.0.0.1';Done=$false},[pscustomobject]@{Guid='test-guid';Family='IPv6';Static='2001:db8::53';Loop='::1';Done=$false})
 ConvertTo-Json -InputObject $rows | Set-Content "$Scratch/Sentinel/network-backup.json"
 $source=Get-Content "$PSScriptRoot/network-lab.ps1" -Raw
 # Unit test only: remove elevation assertion because every network cmdlet above is mocked.
 $source=$source -replace '(?m)^#Requires -RunAsAdministrator\r?\n',''
 & ([scriptblock]::Create($source)) -Restore -Emergency -AcceptLabChanges
 if($script:calls.Count -ne 2){throw "Expected 2 restores, got $($script:calls.Count)"}
 if($script:calls[0] -ne 'IPv4:True:'){throw 'DHCP restore failed'}
 if($script:calls[1] -ne 'IPv6:False:2001:db8::53'){throw 'Static restore failed'}
 $saved=Get-Content "$Scratch/Sentinel/network-backup.json.restored" -Raw | ConvertFrom-Json
 if(@($saved | Where-Object {!$_.Done}).Count){throw 'Journal entries were not restored'}
 'PASS two-family JSON restoration, DHCP, static DNS and Done journal on PowerShell '+$PSVersionTable.PSVersion
}finally{$env:ProgramData=$taskOriginalProgramData}
