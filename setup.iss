; Script generado para Inno Setup
; BEXHA CONTROL - Instalador Profesional

#define MyAppName "BEXHA CONTROL"
#define MyAppVersion "1.0"
#define MyAppPublisher "Spooky Dev"
#define MyAppURL "https://www.spookydev.com"
#define MyAppExeName "BEXHA_CONTROL.exe"

[Setup]
; NOTA: El valor de AppId identifica esta aplicación.
; No uses el mismo AppId en instaladores de otras aplicaciones.
; (Para generar un nuevo GUID, haz clic en Herramientas | Generar GUID en Inno Setup)
AppId={{A1B2C3D4-E5F6-7890-1234-567890ABCDEF}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
; Icono del instalador (debe existir en assets)
SetupIconFile=assets\zapata.ico
; Imagen lateral del instalador (opcional, comentar si no se tiene)
; WizardImageFile=assets\installer_side.bmp
; WizardSmallImageFile=assets\installer_small.bmp
OutputDir=Output
OutputBaseFilename=Instalador_BEXHA_CONTROL
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; El ejecutable principal (generado por build_secure.py)
Source: "dist_secure\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
; Archivo CSV base
Source: "BEXHA.csv"; DestDir: "{app}"; Flags: ignoreversion
; Carpeta de Assets
Source: "assets\*"; DestDir: "{app}\assets"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTA: No copiamos la carpeta 'database' porque se debe crear vacía en la instalación

[Dirs]
; Crear estructura de carpetas vacías
Name: "{app}\database"
Name: "{app}\database\backups"
Name: "{app}\database\documentos"
Name: "{app}\database\recibos"
Name: "{app}\database\reportes"

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
