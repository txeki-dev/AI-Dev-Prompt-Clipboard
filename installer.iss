; Inno Setup Script para AI Dev Prompt Clipboard
; Txek Systems

#define MyAppName "AI Dev Prompt Clipboard"
#define MyAppVersion "1.4.0"
#define MyAppPublisher "Txek Systems"
#define MyAppURL "https://github.com/txeki-dev/AI-Dev-Prompt-Clipboard"

[Setup]
AppId={{E68BC201-9F31-4B74-B32C-9C5B726AA19C}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={localappdata}\Programs\AI-Dev-Prompt-Clipboard
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=dist
OutputBaseFilename=AI-Prompt-Clipboard-Setup
SetupIconFile=icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\icon.ico
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "startupicon"; Description: "Iniciar automáticamente con Windows en segundo plano (Bandeja del sistema)"; GroupDescription: "Opciones de inicio:"

[Files]
Source: "app.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "launch.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "icon.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "version.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "prompts.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "packs\*"; DestDir: "{app}\packs"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "LICENSE"; DestDir: "{app}"; Flags: ignoreversion
; Preservar configuracion local sin sobrescribir en actualizaciones
Source: "config.json"; DestDir: "{app}"; Flags: onlyifdoesntexist

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File ""{app}\app.ps1"""; IconFilename: "{app}\icon.ico"; Comment: "AI Dev Prompt Clipboard"
Name: "{autodesktop}\{#MyAppName}"; Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File ""{app}\app.ps1"""; IconFilename: "{app}\icon.ico"; HotKey: "Ctrl+Alt+P"; Tasks: desktopicon; Comment: "AI Dev Prompt Clipboard (Ctrl+Alt+P)"
Name: "{userstartup}\{#MyAppName}"; Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File ""{app}\app.ps1"" -Startup"; IconFilename: "{app}\icon.ico"; Tasks: startupicon; Comment: "AI Dev Prompt Clipboard (Inicio en segundo plano)"

[Run]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File ""{app}\app.ps1"""; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
