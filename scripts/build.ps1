param([string]$Dotnet='dotnet',[switch]$Publish)
$ErrorActionPreference='Stop'
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
if($Publish){foreach($name in 'Service','UI'){
 & $Dotnet publish "$root/src/Sentinel.$name" -c Release -r win-x64 --self-contained true --no-restore -o "$root/dist/$name"
 if($LASTEXITCODE){throw "Publish failed: $name"}
}}
