#ifndef PackageDir
  #error PackageDir must point to a verified package-windows output directory.
#endif
#ifndef OutputDir
  #error OutputDir is required.
#endif
#ifndef AppVersion
  #error AppVersion is required.
#endif

[Setup]
AppId={{6714E158-757F-4DF0-8D03-35DD27A7489E}
AppName=归宁
AppVersion={#AppVersion}
AppPublisher=归宁项目作者与贡献者
DefaultDirName={localappdata}\Programs\Guining
DefaultGroupName=归宁
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir={#OutputDir}
OutputBaseFilename=Guining-Windows-{#AppVersion}-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
DisableProgramGroupPage=yes
LicenseFile={#PackageDir}\NOTICE.txt
UninstallDisplayIcon={app}\Guining.exe
CloseApplications=no
SetupLogging=yes

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked

[Files]
Source: "{#PackageDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\归宁"; Filename: "{app}\Guining.exe"
Name: "{autodesktop}\归宁"; Filename: "{app}\Guining.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\Guining.exe"; Description: "Play Guining"; Flags: nowait postinstall skipifsilent

; Player saves under APPDATA\Guining are deliberately never installed or deleted.
