param([string]$Dotnet='dotnet')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
& $Dotnet publish "$root/src/Sentinel.UI" -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:EnableCompressionInSingleFile=true -p:RestoreConfigFile="$root/NuGet.Config" -o "$root/app"
if($LASTEXITCODE){throw 'No se pudo publicar la interfaz'}
Copy-Item "$root/app/SENTINEL.exe" "$root/SENTINEL.exe" -Force
