; token2-companion.iss — Inno Setup script for the Windows installer.
;
; Produces a single Setup .exe that installs the rebranded keyroost GUI (and the
; CLI), creates Start Menu / optional desktop shortcuts, and registers an
; uninstaller. Compile with the Inno Setup Compiler (iscc.exe) — see
; build-installer.ps1, which fills in the paths and invokes it.
;
; The placeholders @VAR@ are substituted by build-installer.ps1 before compiling,
; so this file stays generic and the script carries the real values.

#define AppName       "@APP_NAME@"
#define AppId         "@APP_ID@"
#define AppVersion    "@APP_VERSION@"
#define AppPublisher  "Token2"
#define AppExe        "keyroost.exe"
#define CliExe        "keyroostctl.exe"
#define SrcDir        "@SRC_DIR@"
#define IconFile      "@ICON_FILE@"
#define OutputDir     "@OUTPUT_DIR@"

[Setup]
AppId={{#AppId}}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=token2-companion-keyroost-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; Per-machine if elevated, per-user otherwise.
PrivilegesRequiredOverridesAllowed=dialog
SetupIconFile={#IconFile}
UninstallDisplayIcon={app}\{#AppExe}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "{#SrcDir}\{#AppExe}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SrcDir}\{#CliExe}"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent
