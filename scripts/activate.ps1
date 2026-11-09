#Requires -RunAsAdministrator
$ErrorActionPreference='Stop'
if(Get-Service Sentinel -ErrorAction SilentlyContinue){exit 2}
try {
 & "$PSScriptRoot/install-lab.ps1" -AcceptLabChanges
 Resolve-DnsName example.com -Server 127.0.0.1 -Type A -DnsOnly -QuickTimeout | Out-Null
 & "$PSScriptRoot/network-lab.ps1" -Apply -AcceptLabChanges
 Resolve-DnsName example.com -Type A -DnsOnly -QuickTimeout | Out-Null
 exit 0
}catch{
 $message=$_.Exception.Message
 try { & "$PSScriptRoot/remove-lab.ps1" -Emergency -AcceptLabChanges } catch { $message+="; recuperación pendiente: $($_.Exception.Message)" }
 Add-Type -AssemblyName PresentationFramework
 [System.Windows.MessageBox]::Show($message,'SENTINEL: activación incompleta') | Out-Null
 exit 1
}
