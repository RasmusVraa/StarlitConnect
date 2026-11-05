[Setup]
AppId={{BD0048C0-FD65-44F0-9AD4-7C007D42BCE8}
AppName=StarlitConnect
AppVersion=1.0.0
AppVerName=StarlitConnect 1.0.0
AppPublisher=StarlitVPN
AppPublisherURL=https://internet.starlit-moon.ru
AppSupportURL=https://t.me/starlitvpnbot
DefaultDirName={autopf}\StarlitConnect
DisableProgramGroupPage=yes
OutputDir=C:\src\StarlitConnect\dist
OutputBaseFilename=StarlitConnect-Setup
SetupIconFile=C:\src\StarlitConnect\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\StarlitConnect.exe
UninstallDisplayName=StarlitConnect

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\app_links_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\concrt140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\connectivity_plus_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\dartjni.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\dynamic_color_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\EnableLoopback.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\file_selector_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\FlClashCore.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\FlClashHelperService.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\manifest.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\msvcp140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\msvcp140_1.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\msvcp140_2.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\msvcp140_atomic_wait.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\msvcp140_codecvt_ids.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\proxy_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\rust_api.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\screen_retriever_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\sqlite3.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\StarlitConnect.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\tray_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\url_launcher_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\vcruntime140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\vcruntime140_1.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\wifi_ssid_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\window_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\app.so"; DestDir: "{app}\data"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\icudtl.dat"; DestDir: "{app}\data"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\AssetManifest.bin"; DestDir: "{app}\data\flutter_assets"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\FontManifest.json"; DestDir: "{app}\data\flutter_assets"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\NativeAssetsManifest.json"; DestDir: "{app}\data\flutter_assets"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\NOTICES.Z"; DestDir: "{app}\data\flutter_assets"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\assets\data\ASN.mmdb"; DestDir: "{app}\data\flutter_assets\assets\data"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\assets\data\GEOIP.dat"; DestDir: "{app}\data\flutter_assets\assets\data"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\assets\data\GEOIP.metadb"; DestDir: "{app}\data\flutter_assets\assets\data"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\assets\data\GEOSITE.dat"; DestDir: "{app}\data\flutter_assets\assets\data"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\assets\fonts\JetBrainsMono-Regular.ttf"; DestDir: "{app}\data\flutter_assets\assets\fonts"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\assets\fonts\Twemoji.Mozilla.ttf"; DestDir: "{app}\data\flutter_assets\assets\fonts"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\assets\images\icon.ico"; DestDir: "{app}\data\flutter_assets\assets\images"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\assets\images\icon.png"; DestDir: "{app}\data\flutter_assets\assets\images"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\assets\images\avatar\arue.jpg"; DestDir: "{app}\data\flutter_assets\assets\images\avatar"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\assets\images\avatar\june2.jpg"; DestDir: "{app}\data\flutter_assets\assets\images\avatar"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\assets\images\services\bilibili.svg"; DestDir: "{app}\data\flutter_assets\assets\images\services"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\assets\images\services\claude.svg"; DestDir: "{app}\data\flutter_assets\assets\images\services"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\assets\images\services\discord.svg"; DestDir: "{app}\data\flutter_assets\assets\images\services"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\assets\images\services\disneyplus.svg"; DestDir: "{app}\data\flutter_assets\assets\images\services"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\assets\images\services\gemini.svg"; DestDir: "{app}\data\flutter_assets\assets\images\services"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\assets\images\services\github.svg"; DestDir: "{app}\data\flutter_assets\assets\images\services"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\assets\images\services\google.svg"; DestDir: "{app}\data\flutter_assets\assets\images\services"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\assets\images\services\LICENSE.md"; DestDir: "{app}\data\flutter_assets\assets\images\services"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\assets\images\services\netflix.svg"; DestDir: "{app}\data\flutter_assets\assets\images\services"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\assets\images\services\openai.svg"; DestDir: "{app}\data\flutter_assets\assets\images\services"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\assets\images\services\primevideo.svg"; DestDir: "{app}\data\flutter_assets\assets\images\services"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\assets\images\services\spotify.svg"; DestDir: "{app}\data\flutter_assets\assets\images\services"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\assets\images\services\tiktok.svg"; DestDir: "{app}\data\flutter_assets\assets\images\services"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\assets\images\services\youtube.svg"; DestDir: "{app}\data\flutter_assets\assets\images\services"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\assets\images\tray\windows\status_1.ico"; DestDir: "{app}\data\flutter_assets\assets\images\tray\windows"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\assets\images\tray\windows\status_2.ico"; DestDir: "{app}\data\flutter_assets\assets\images\tray\windows"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\assets\images\tray\windows\status_3.ico"; DestDir: "{app}\data\flutter_assets\assets\images\tray\windows"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\assets\images\tray\windows\status_4.ico"; DestDir: "{app}\data\flutter_assets\assets\images\tray\windows"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\core\Clash.Meta\component\ca\ca-certificates.crt"; DestDir: "{app}\data\flutter_assets\core\Clash.Meta\component\ca"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\packages\prism_ui\shaders\ink_sparkle.frag"; DestDir: "{app}\data\flutter_assets\packages\prism_ui\shaders"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\packages\prism_ui\shaders\liquid_glass.frag"; DestDir: "{app}\data\flutter_assets\packages\prism_ui\shaders"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\shaders\ink_sparkle.frag"; DestDir: "{app}\data\flutter_assets\shaders"; Flags: ignoreversion
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\data\flutter_assets\shaders\stretch_effect.frag"; DestDir: "{app}\data\flutter_assets\shaders"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\StarlitConnect"; Filename: "{app}\StarlitConnect.exe"
Name: "{autodesktop}\StarlitConnect"; Filename: "{app}\StarlitConnect.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\StarlitConnect.exe"; Description: "Запустить StarlitConnect"; Flags: nowait postinstall skipifsilent

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssInstall then
  begin
    Exec('taskkill', '/f /im StarlitConnect.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Exec('taskkill', '/f /im FlClashCore.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;
