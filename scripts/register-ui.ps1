#Requires -RunAsAdministrator
$ErrorActionPreference='Stop'
$target=Join-Path $env:ProgramFiles 'Sentinel'
$key='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Sentinel'
$command='"'+$target+'\UI\SENTINEL.exe" --uninstall'
if(Test-Path $key){
 $previous=(Get-ItemProperty $key -Name UninstallString -ErrorAction SilentlyContinue).UninstallString
 if($previous -and $previous -ne $command){throw 'Entrada de desinstalación ajena; no se modifica.'}
}
New-Item $key -Force | Out-Null
foreach($row in @(@('DisplayName','SENTINEL - protección DNS'),@('DisplayVersion','0.5.0'),@('UninstallString',$command),@('DisplayIcon',($target+'\UI\SENTINEL.exe')))){
 New-ItemProperty $key $row[0] -Value $row[1] -PropertyType String -Force | Out-Null
}
foreach($name in 'NoModify','NoRepair'){New-ItemProperty $key $name -Value 1 -PropertyType DWord -Force | Out-Null}
$owner=(Get-Content (Join-Path $env:ProgramData 'Sentinel/owner.txt') -Raw).Trim()
$null=[Security.Principal.SecurityIdentifier]::new($owner)
$userHive='Registry::HKEY_USERS\'+$owner
if(!(Test-Path -LiteralPath $userHive)){throw 'La sesión del propietario no está cargada; no se registra el panel en una cuenta distinta.'}
$run=$userHive+'\Software\Microsoft\Windows\CurrentVersion\Run'
$ui='"'+$target+'\UI\SENTINEL.exe"'
$previous=(Get-ItemProperty $run -Name Sentinel -ErrorAction SilentlyContinue).Sentinel
if($previous -and $previous -ne $ui){throw 'Entrada de arranque ajena; no se modifica.'}
New-Item $run -Force | Out-Null
New-ItemProperty $run Sentinel -Value $ui -PropertyType String -Force | Out-Null
