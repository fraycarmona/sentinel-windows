; Development GUI package: deliberately does not silently enable unvalidated machine networking.
[Setup]
AppId=Sentinel-Lab-Prototype
AppName=SENTINEL Laboratorio
AppVersion=0.1.0
DefaultDirName={localappdata}\Sentinel-Lab
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\dist\Installer
OutputBaseFilename=Sentinel-Lab-Setup
Uninstallable=yes
WizardStyle=modern
[Files]
Source: "..\dist\Service\*"; DestDir: "{app}\dist\Service"; Flags: recursesubdirs
Source: "..\dist\UI\*"; DestDir: "{app}\dist\UI"; Flags: recursesubdirs
Source: "..\scripts\*"; DestDir: "{app}\scripts"
Source: "..\config\*"; DestDir: "{app}\config"
Source: "..\docs\*"; DestDir: "{app}\docs"
[Icons]
Name: "{group}\SENTINEL Â· Interfaz demo"; Filename: "{app}\dist\UI\SENTINEL.exe"; Parameters: "--demo"
; This uninstaller removes only the portable lab package, not the installed service.
; Production MSI with one enforced 24h flow remains a release gate.
