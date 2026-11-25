param([string]$Dotnet='dotnet',[switch]$Publish,[switch]$InstallerPayload)
$ErrorActionPreference='Stop'
if($InstallerPayload -and !$Publish){throw 'InstallerPayload requiere -Publish.'}
$env:DOTNET_CLI_TELEMETRY_OPTOUT='1'
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE='1'
$root=Split-Path $PSScriptRoot
foreach($name in 'Core','Service','UI','Tests') {
 $proj=Join-Path $root "src/Sentinel.$name"
 & $Dotnet restore $proj --configfile "$root/NuGet.Config" -r win-x64
 if($LASTEXITCODE){throw "Restore failed: $name"}
 & $Dotnet build $proj -c Release --no-restore -r win-x64
 if($LASTEXITCODE){throw "Build failed: $name"}
}
& $Dotnet run --project "$root/src/Sentinel.Tests" -c Release --no-restore -r win-x64
if($LASTEXITCODE){throw 'Tests failed'}
if($Publish){
 $runtimes=if($InstallerPayload){'win-x64','win-arm64'}else{'win-x64'}
 foreach($rid in $runtimes){
  foreach($name in 'Service','UI'){
   $project="$root/src/Sentinel.$name"
   $output=if($InstallerPayload){"$root/dist/$rid/$name"}else{"$root/dist/$name"}
   & $Dotnet restore $project --configfile "$root/NuGet.Config" -r $rid -p:SelfContained=true
   if($LASTEXITCODE){throw "Publish restore failed: $name ($rid)"}
   & $Dotnet publish $project -c Release -r $rid --self-contained true --no-restore -o $output
   if($LASTEXITCODE){throw "Publish failed: $name ($rid)"}
  }
 }
}
