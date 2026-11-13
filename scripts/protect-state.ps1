#Requires -RunAsAdministrator
$ErrorActionPreference='Stop'
$data=Join-Path $env:ProgramData 'Sentinel'
if((Get-Service Sentinel).Status -ne 'Stopped'){throw 'Proteja el estado con el servicio detenido.'}
& sc.exe sidtype Sentinel unrestricted | Out-Null
if($LASTEXITCODE){throw 'No se pudo configurar SID propio.'}
$sid=([Security.Principal.NTAccount]::new('NT SERVICE','Sentinel')).Translate([Security.Principal.SecurityIdentifier]).Value
$runtime=Join-Path $data 'runtime'
New-Item -ItemType Directory $runtime -Force | Out-Null
if(!(Test-Path "$runtime/lock.json")){
 if(!(Test-Path "$data/lock.json")){throw 'Falta estado: no se crea una espera nueva ni se concede retirada.'}
 Move-Item -LiteralPath "$data/lock.json" -Destination "$runtime/lock.json"
}
# Root/configuration/journals are writable only by SYSTEM and Administrators.
$acl=[Security.AccessControl.DirectorySecurity]::new()
$acl.SetAccessRuleProtection($true,$false)
foreach($entry in @(@('S-1-5-18','FullControl'),@('S-1-5-32-544','FullControl'),@($sid,'ReadAndExecute'))){
 $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new($entry[0]),$entry[1],'ContainerInherit,ObjectInherit','None','Allow'))
}
Set-Acl -LiteralPath $data -AclObject $acl
# Reset old inherited/shared LocalService grants, including atomic-write files.
& icacls.exe "$data\*" /reset /T /C | Out-Null
if($LASTEXITCODE){throw 'No se pudieron restringir los archivos existentes.'}
& icacls.exe $runtime /grant:r ('*'+$sid+':(OI)(CI)M') | Out-Null
if($LASTEXITCODE){throw 'No se pudo asignar escritura al estado propio del servicio.'}
