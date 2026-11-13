#Requires -RunAsAdministrator
$ErrorActionPreference='Stop'
$existing=[bool](Get-Service Sentinel -ErrorAction SilentlyContinue)
try {
 if($existing){& "$PSScriptRoot/repair-service.ps1"}else{
  & "$PSScriptRoot/install-lab.ps1" -AcceptLabChanges
  & "$PSScriptRoot/register-guardian.ps1"
 }
 # Check repeatedly before making the machine depend on this resolver.
 foreach($attempt in 1..5){
  Resolve-DnsName example.com -Server 127.0.0.1 -Type A -DnsOnly -QuickTimeout | Out-Null
  Start-Sleep -Seconds 1
 }
 & "$PSScriptRoot/hosts-lab.ps1" -Mode Apply
 if(!(Test-Path (Join-Path $env:ProgramData 'Sentinel/strict-backup.json'))){& "$PSScriptRoot/strict-lab.ps1" -Mode Apply -AcceptLabChanges}
 & "$PSScriptRoot/network-lab.ps1" -Apply -AcceptLabChanges
 Resolve-DnsName example.com -Type A -DnsOnly -QuickTimeout | Out-Null
 exit 0
}catch{
 $message=$_.Exception.Message
 try {
  if($existing){& "$PSScriptRoot/network-lab.ps1" -Fallback -AcceptLabChanges}
  else{& "$PSScriptRoot/remove-lab.ps1" -Emergency -AcceptLabChanges}
 } catch { $message+="; recuperación pendiente: $($_.Exception.Message)" }
 try{[IO.File]::WriteAllText((Join-Path $env:ProgramData 'Sentinel/activation-error.txt'),$message)}catch{}
 Add-Type -AssemblyName PresentationFramework
 [System.Windows.MessageBox]::Show($message,'SENTINEL: activación incompleta') | Out-Null
 exit 1
}
