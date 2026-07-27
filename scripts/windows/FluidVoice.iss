; Inno Setup script for FluidVoice Windows.
; Build Release first, then compile with ISCC.exe.
; Example:
;   iscc scripts\windows\FluidVoice.iss

#define MyAppName "FluidVoice"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "FluidVoice"
#define MyAppExeName "fluidvoice_app.exe"

; Override via ISCC /DReleaseDir=...
#ifndef ReleaseDir
  #define ReleaseDir "C:\dev\FluidVoice_Port_to_Windows\flutter_app\build\windows\x64\runner\Release"
#endif

#ifndef OutputDir
  #define OutputDir "C:\dev\FluidVoice_Port_to_Windows\dist"
#endif

[Setup]
AppId={{A7C3E2F1-9B4D-4E8A-9C21-6F1B0D2E8A11}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=FluidVoice-Windows-Setup-{#MyAppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
