#ifndef SentinelVersion
  #define SentinelVersion "0.5.0"
#endif

[Setup]
AppId=SentinelSetup
AppName=SENTINEL
AppVersion={#SentinelVersion}
DefaultDirName={autopf}\Sentinel
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=admin
MinVersion=10.0.22000
ArchitecturesAllowed=x64compatible or arm64
ArchitecturesInstallIn64BitMode=x64compatible or arm64
SetupMutex=Global\SentinelSetup
CreateUninstallRegKey=no
SetupLogging=yes
UninstallLogging=yes
OutputDir=..\dist\Installer
OutputBaseFilename=Sentinel-Setup
SetupIconFile=..\assets\sentinel.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Messages]
ReadyLabel1=El instalador activará el filtrado DNS y aplicará controles de navegador y firewall. La retirada ordinaria requiere 24 horas acumuladas con el servicio en marcha desde que se solicita.

[Files]
Source: "..\dist\win-x64\Service\*"; DestDir: "{app}\Service"; Flags: recursesubdirs; Check: not IsArm64
Source: "..\dist\win-x64\UI\*"; DestDir: "{app}\UI"; Flags: recursesubdirs; Check: not IsArm64
Source: "..\dist\win-arm64\Service\*"; DestDir: "{app}\Service"; Flags: recursesubdirs; Check: IsArm64
Source: "..\dist\win-arm64\UI\*"; DestDir: "{app}\UI"; Flags: recursesubdirs; Check: IsArm64
Source: "configure.ps1"; DestDir: "{app}\scripts"
Source: "..\scripts\install-lab.ps1"; DestDir: "{app}\scripts"
Source: "..\scripts\remove-lab.ps1"; DestDir: "{app}\scripts"
Source: "..\scripts\protect-state.ps1"; DestDir: "{app}\scripts"
Source: "..\scripts\register-guardian.ps1"; DestDir: "{app}\scripts"
Source: "..\scripts\dns-guardian.ps1"; DestDir: "{app}\scripts"
Source: "..\scripts\verify-startup.ps1"; DestDir: "{app}\scripts"
Source: "..\scripts\network-lab.ps1"; DestDir: "{app}\scripts"
Source: "..\scripts\hosts-lab.ps1"; DestDir: "{app}\scripts"
Source: "..\scripts\strict-lab.ps1"; DestDir: "{app}\scripts"
Source: "..\scripts\browser-lab.ps1"; DestDir: "{app}\scripts"
Source: "..\scripts\PipeIdentity.cs"; DestDir: "{app}\scripts"
Source: "..\scripts\*.psm1"; DestDir: "{app}\scripts"
Source: "..\config\rules.json"; DestDir: "{app}\config"
Source: "..\docs\recovery.md"; DestDir: "{app}\docs"

[Icons]
Name: "{commonprograms}\SENTINEL"; Filename: "{app}\UI\SENTINEL.exe"
Name: "{userstartup}\SENTINEL"; Filename: "{app}\UI\SENTINEL.exe"

[Registry]
#define UninstallKey "Software\Microsoft\Windows\CurrentVersion\Uninstall\SentinelSetup"
Root: HKLM; Subkey: "{#UninstallKey}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "{#UninstallKey}"; ValueType: string; ValueName: "DisplayName"; ValueData: "SENTINEL"
Root: HKLM; Subkey: "{#UninstallKey}"; ValueType: string; ValueName: "DisplayVersion"; ValueData: "{#SentinelVersion}"
Root: HKLM; Subkey: "{#UninstallKey}"; ValueType: string; ValueName: "DisplayIcon"; ValueData: "{app}\UI\SENTINEL.exe"
Root: HKLM; Subkey: "{#UninstallKey}"; ValueType: string; ValueName: "InstallLocation"; ValueData: "{app}"
Root: HKLM; Subkey: "{#UninstallKey}"; ValueType: string; ValueName: "UninstallString"; ValueData: """{app}\UI\SENTINEL.exe"" --uninstall"
Root: HKLM; Subkey: "{#UninstallKey}"; ValueType: dword; ValueName: "NoModify"; ValueData: "1"
Root: HKLM; Subkey: "{#UninstallKey}"; ValueType: dword; ValueName: "NoRepair"; ValueData: "1"

[Run]
Filename: "{app}\UI\SENTINEL.exe"; Description: "Abrir SENTINEL"; Flags: postinstall nowait skipifsilent runasoriginaluser; Check: ActivationSucceeded

[Code]
var
  ActivationExitCode: Integer;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  if CompareText(WizardDirValue, ExpandConstant('{autopf}\Sentinel')) <> 0 then
    Result := 'SENTINEL requiere su carpeta de instalación en Archivos de programa.'
  else if FileOrDirExists(WizardDirValue) or
          FileOrDirExists(ExpandConstant('{commonappdata}\Sentinel')) or
          RegKeyExists(HKLM, 'SYSTEM\CurrentControlSet\Services\Sentinel') or
          RegKeyExists(HKLM, '{#UninstallKey}') or
          RegKeyExists(HKLM, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\Sentinel') then
    Result := 'Ya existe una instalación o una recuperación pendiente. Consulte la documentación de SENTINEL.';
end;

function RunConfiguration(Operation: String): Integer;
var
  ExitCode: Integer;
begin
  if ExecAndLogOutputWithNativeSysDir(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
    '-NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File "' +
      ExpandConstant('{app}\scripts\configure.ps1') + '" -Operation ' + Operation,
    ExpandConstant('{app}'), SW_SHOWNORMAL, ewWaitUntilTerminated, ExitCode, nil) then
    Result := ExitCode
  else
  begin
    Log('No se pudo iniciar PowerShell. Código de Windows: ' + IntToStr(ExitCode));
    Result := 1;
  end;
  Log('Configuración de SENTINEL (' + Operation + '): ' + IntToStr(Result));
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    WizardForm.StatusLabel.Caption := 'Activando y verificando el filtrado DNS…';
    ActivationExitCode := RunConfiguration('Install');
    if ActivationExitCode <> 0 then
      SuppressibleMsgBox('No se completó la activación. Consulte docs\recovery.md en la carpeta de SENTINEL. ' +
        'Si se requiere restauración, se conservan los scripts y los diarios para completarla.',
        mbError, MB_OK, IDOK);
  end;
end;

function ActivationSucceeded: Boolean;
begin
  Result := ActivationExitCode = 0;
end;

function GetCustomSetupExitCode: Integer;
begin
  Result := ActivationExitCode;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  ExitCode: Integer;
begin
  if CurUninstallStep <> usUninstall then
    Exit;
  ExitCode := RunConfiguration('Remove');
  if ExitCode <> 0 then
  begin
    if ExitCode = 24 then
      SuppressibleMsgBox('Solicite la retirada en SENTINEL y complete las 24 horas de servicio activo.',
        mbError, MB_OK, IDOK)
    else
      SuppressibleMsgBox('No se completó la restauración. Consulte docs\recovery.md en la carpeta de SENTINEL.',
        mbError, MB_OK, IDOK);
    Abort;
  end;
end;
