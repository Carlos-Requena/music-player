; Instalador de Windows del reproductor (Inno Setup 6). Lo compila
; scripts/crear-instalador-windows.ps1, que prepara antes la carpeta `Origen` con el programa,
; Qt, mpv, yt-dlp y deno. A mano:
;
;   ISCC.exe /DVersion=0.1.0 /DOrigen=C:\ruta\a\la\carpeta scripts\windows\reproductor.iss
;
; Se instala para el usuario, sin permisos de administrador, en
; %LOCALAPPDATA%\Programs\Reproductor. Desinstalar no borra las preferencias ni la sesión
; (%APPDATA%\musicplayer) ni la caché (%LOCALAPPDATA%\musicplayer).

#ifndef Version
  #define Version "0.1.0"
#endif
#ifndef Origen
  #error Falta /DOrigen=<carpeta preparada por crear-instalador-windows.ps1>
#endif

[Setup]
AppId={{7A8B2E4C-5D1F-4E6A-9C3B-2F0D8E1A6B57}
AppName=Reproductor de música
AppVersion={#Version}
AppPublisher=Reproductor de música
DefaultDirName={localappdata}\Programs\Reproductor
DefaultGroupName=Reproductor de música
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Windows 10 1809 o superior (WebView2 y los controles multimedia del sistema).
MinVersion=10.0.17763
OutputDir=..\..\target\windows
OutputBaseFilename=Reproductor-{#Version}-instalador
SetupIconFile=..\..\assets\icon.ico
UninstallDisplayIcon={app}\musicplayer.exe
UninstallDisplayName=Reproductor de música
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; Cierra el reproductor si está abierto al actualizar o desinstalar.
CloseApplications=yes

[Languages]
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "escritorio"; Description: "Crear un acceso directo en el escritorio"; Flags: unchecked

[Files]
Source: "{#Origen}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\assets\icon.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\Reproductor de música"; Filename: "{app}\musicplayer.exe"; IconFilename: "{app}\icon.ico"
Name: "{autodesktop}\Reproductor de música"; Filename: "{app}\musicplayer.exe"; IconFilename: "{app}\icon.ico"; Tasks: escritorio

[Run]
Filename: "{app}\musicplayer.exe"; Description: "Abrir el reproductor"; Flags: nowait postinstall skipifsilent
