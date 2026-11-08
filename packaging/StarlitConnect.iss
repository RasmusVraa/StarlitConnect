[Setup]
AppId={{BD0048C0-FD65-44F0-9AD4-7C007D42BCE8}
AppName=StarlitConnect
AppVersion=1.1.6
AppVerName=StarlitConnect 1.1.6
AppPublisher=StarlitVPN
AppPublisherURL=https://internet.starlit-moon.ru
AppSupportURL=https://t.me/starlitvpnbot
DefaultDirName={autopf}\StarlitConnect
DisableProgramGroupPage=yes
UsePreviousAppDir=yes
DirExistsWarning=no
CloseApplications=force
RestartApplications=no
OutputDir=C:\src\StarlitConnect\dist
OutputBaseFilename=StarlitConnect-1.1.6-windows-amd64-setup
SetupIconFile=C:\src\StarlitConnect\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\StarlitConnect.exe
UninstallDisplayName=StarlitConnect

[Code]
const
  SYNCHRONIZE = $00100000;

function OpenProcess(dwDesiredAccess: DWORD; bInheritHandle: BOOL; dwProcessId: DWORD): THandle;
  external 'OpenProcess@kernel32.dll stdcall';
function WaitForSingleObject(hHandle: THandle; dwMilliseconds: DWORD): DWORD;
  external 'WaitForSingleObject@kernel32.dll stdcall';
function CloseHandle(hObject: THandle): BOOL;
  external 'CloseHandle@kernel32.dll stdcall';

function UpdatingAppPid: Integer;
begin
  Result := StrToIntDef(ExpandConstant('{param:updatefrom|0}'), 0);
end;

function IsAppUpdate: Boolean;
begin
  Result := UpdatingAppPid > 0;
end;

procedure WaitForUpdatingApp;
var
  Handle: THandle;
begin
  if not IsAppUpdate then
    Exit;
  Handle := OpenProcess(SYNCHRONIZE, False, UpdatingAppPid);
  if Handle <> 0 then
  begin
    WaitForSingleObject(Handle, 20000);
    CloseHandle(Handle);
  end;
end;

procedure KillProcesses;
var
  Processes: TArrayOfString;
  i: Integer;
  ResultCode: Integer;
begin
  Processes := ['StarlitConnect.exe', 'FlClash.exe', 'FlClashCore.exe', 'FlClashHelperService.exe'];
  for i := 0 to GetArrayLength(Processes)-1 do
  begin
    Exec('taskkill', '/f /im ' + Processes[i], '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;

procedure UnregisterHelperService;
var
  HelperPath: String;
  ResultCode: Integer;
begin
  HelperPath := ExpandConstant('{app}\FlClashHelperService.exe');
  if FileExists(HelperPath) then
  begin
    Exec(HelperPath, 'uninstall', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;

procedure ClearStaleProxy;
var
  AppPath: String;
  ResultCode: Integer;
begin
  AppPath := ExpandConstant('{app}\StarlitConnect.exe');
  if FileExists(AppPath) then
  begin
    Exec(AppPath, '--clear-stale-proxy', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;

function PointsIntoApp(Value: String): Boolean;
begin
  Result := Pos(Lowercase(AddBackslash(ExpandConstant('{app}'))), Lowercase(Value)) > 0;
end;

procedure RemoveUserRegistrations;
var
  Schemes: TArrayOfString;
  Value: String;
  i: Integer;
begin
  if RegQueryStringValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run', 'StarlitConnect', Value) and PointsIntoApp(Value) then
  begin
    RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run', 'StarlitConnect');
    RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run', 'StarlitConnect');
  end;

  Schemes := ['clash', 'clashmeta', 'flclash'];
  for i := 0 to GetArrayLength(Schemes)-1 do
  begin
    if RegQueryStringValue(HKCU, 'Software\Classes\' + Schemes[i] + '\shell\open\command', '', Value) and PointsIntoApp(Value) then
    begin
      RegDeleteKeyIncludingSubkeys(HKCU, 'Software\Classes\' + Schemes[i]);
    end;
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  WaitForUpdatingApp;
  UnregisterHelperService;
  KillProcesses;
  Result := '';
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    ClearStaleProxy;
  end;
end;

function InitializeUninstall(): Boolean;
begin
  UnregisterHelperService;
  KillProcesses;
  ClearStaleProxy;
  Result := True;
end;

procedure RemoveUserData;
begin
  DelTree(ExpandConstant('{userappdata}\StarlitVPN\StarlitConnect'), True, True, True);
  DelTree(ExpandConstant('{localappdata}\StarlitVPN\StarlitConnect'), True, True, True);
  RemoveDir(ExpandConstant('{userappdata}\StarlitVPN'));
  RemoveDir(ExpandConstant('{localappdata}\StarlitVPN'));
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    RemoveUserRegistrations;
    if not UninstallSilent and (MsgBox(CustomMessage('RemoveUserData'), mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES) then
    begin
      RemoveUserData;
    end;
  end;
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := IsAppUpdate and ((PageID = wpSelectDir) or (PageID = wpSelectTasks) or (PageID = wpReady));
end;

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[CustomMessages]
english.RemoveUserData=Also delete your profiles and settings?
russian.RemoveUserData=????? ??????? ??????? ? ??????????

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "C:\src\StarlitConnect\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\StarlitConnect"; Filename: "{app}\StarlitConnect.exe"
Name: "{autodesktop}\StarlitConnect"; Filename: "{app}\StarlitConnect.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\StarlitConnect.exe"; Description: "{cm:LaunchProgram,StarlitConnect}"; Flags: runascurrentuser nowait postinstall skipifsilent; Check: not IsAppUpdate
Filename: "{app}\StarlitConnect.exe"; Flags: runascurrentuser nowait; Check: IsAppUpdate
