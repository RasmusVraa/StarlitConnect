# Rebuild StarlitConnect Windows app + installer.
# If Doctor Web locks .obj under Projects, build from C:\src\StarlitConnect (mirror).

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
if (Test-Path "C:\src\StarlitConnect\pubspec.yaml") { $root = "C:\src\StarlitConnect" }

$vcvars = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
$pubBin = "$env:LOCALAPPDATA\Pub\Cache\bin"
$winlibs = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\BrechtSanders.WinLibs.POSIX.UCRT*\mingw64\bin" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
$iscc = "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
$flutter = "C:\Users\Michail\flutter\bin"

$bat = @"
@echo off
call "$vcvars"
set PATH=C:\Program Files\CMake\bin;$pubBin;$flutter;C:\Users\Michail\.cargo\bin;$winlibs;%PATH%
set CMAKE_BUILD_PARALLEL_LEVEL=1
cd /d "$root"
if not exist env.json echo {"APP_ENV":"pre"}>env.json
flutter pub get || exit /b 1
flutter build windows --release --dart-define-from-file=env.json || exit /b 1
"@
$tmp = "$env:TEMP\starlit-rebuild.bat"
Set-Content $tmp $bat -Encoding ASCII
cmd /c $tmp
if ($LASTEXITCODE -ne 0) { throw "flutter build failed: $LASTEXITCODE" }

Write-Host "App built. Refresh packaging\StarlitConnect.iss file list if needed, then:"
Write-Host "& `"$iscc`" `"$root\packaging\StarlitConnect.iss`""
