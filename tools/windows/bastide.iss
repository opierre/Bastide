; Inno Setup script for the Windows installer: `Bastide-Setup-<version>.exe`.
;
; Built by `uv run tools/package_app.py`, which passes the defines below. By hand:
;   iscc /DAppVersion=0.1.0 /DSourceDir=<release folder> /DOutputDir=<folder> tools\windows\bastide.iss
;
; Per-user install, no admin rights: into %LOCALAPPDATA%\Programs\Bastide. The user's data lives
; in %LOCALAPPDATA%\Bastide (platformdirs, backend/app/core/config.py), outside {app}, and the
; uninstaller only removes what this script installed, so uninstalling never touches it.

#ifndef AppVersion
  #error Pass the product version: /DAppVersion=<version>
#endif
#ifndef SourceDir
  #error Pass the Flutter release folder: /DSourceDir=<path>
#endif
#ifndef NumericVersion
  #define NumericVersion AppVersion
#endif
#ifndef OutputDir
  #define OutputDir "."
#endif

[Setup]
; Upgrades find the installed copy by this id. Never change it.
AppId={{2BD27D4C-7D6B-46B4-B63A-8614EB4B374A}
AppName=Bastide
AppVersion={#AppVersion}
AppVerName=Bastide {#AppVersion}
AppPublisher=Bastide
AppPublisherURL=https://github.com/opierre/Bastide
AppSupportURL=https://github.com/opierre/Bastide/issues
VersionInfoVersion={#NumericVersion}
VersionInfoProductName=Bastide
VersionInfoDescription=Bastide installer

PrivilegesRequired=lowest
DefaultDirName={localappdata}\Programs\Bastide
DisableProgramGroupPage=yes
DefaultGroupName=Bastide
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0

; The app holds this mutex while it runs (frontend/windows/runner/main.cpp), so Setup and the
; uninstaller ask the user to close it rather than overwrite files in use. The Restart Manager
; covers whatever the mutex misses, the backend included.
AppMutex=Local\Bastide.SingleInstance
CloseApplications=yes
RestartApplications=no

SetupIconFile=..\..\frontend\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\bastide.exe
UninstallDisplayName=Bastide
WizardStyle=modern
ShowLanguageDialog=auto
Compression=lzma2/max
SolidCompression=yes
OutputDir={#OutputDir}
OutputBaseFilename=Bastide-Setup-{#AppVersion}

[Languages]
Name: "fr"; MessagesFile: "compiler:Languages\French.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[InstallDelete]
; An upgrade replaces the frozen backend wholesale, so no module from the previous version lingers.
Type: filesandordirs; Name: "{app}\backend"

[Icons]
Name: "{autoprograms}\Bastide"; Filename: "{app}\bastide.exe"
Name: "{autodesktop}\Bastide"; Filename: "{app}\bastide.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\bastide.exe"; Description: "{cm:LaunchProgram,Bastide}"; Flags: nowait postinstall skipifsilent
