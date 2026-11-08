# Rebuild StarlitConnect Windows app + installer (Xray core).
# If Doctor Web locks .obj under Projects, build from C:\src\StarlitConnect (mirror).

$ErrorActionPreference = "Stop"
$project = Split-Path $PSScriptRoot -Parent
$root = $project
# Prefer the Doctor-Web-safe mirror when present, but keep it in sync with Projects.
if (Test-Path "C:\src\StarlitConnect\pubspec.yaml") {
  $root = "C:\src\StarlitConnect"
  Write-Host "Syncing $project -> $root (lib, core, assets, packaging, pubspec, third_party)"
  robocopy "$project\lib" "$root\lib" /E /XO /NFL /NDL /NJH /NJS /R:1 /W:1 | Out-Null
  robocopy "$project\core" "$root\core" /E /XO /NFL /NDL /NJH /NJS /R:1 /W:1 | Out-Null
  robocopy "$project\assets" "$root\assets" /E /XO /NFL /NDL /NJH /NJS /R:1 /W:1 | Out-Null
  robocopy "$project\packaging" "$root\packaging" /E /XO /NFL /NDL /NJH /NJS /R:1 /W:1 | Out-Null
  if (Test-Path "$project\third_party") {
    robocopy "$project\third_party" "$root\third_party" /E /XO /NFL /NDL /NJH /NJS /R:1 /W:1 | Out-Null
  }
  Copy-Item "$project\pubspec.yaml" "$root\pubspec.yaml" -Force
}

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
call flutter pub get || exit /b 1
call flutter build windows --release --dart-define-from-file=env.json || exit /b 1
"@
$tmp = "$env:TEMP\starlit-rebuild.bat"
Set-Content $tmp $bat -Encoding ASCII
cmd /c $tmp
if ($LASTEXITCODE -ne 0) { throw "flutter build failed: $LASTEXITCODE" }

$release = Join-Path $root "build\windows\x64\runner\Release"
$xraySrc = Join-Path $project "third_party\xray"
$xrayDst = Join-Path $release "xray"
New-Item -ItemType Directory -Force -Path $xrayDst | Out-Null
if (Test-Path (Join-Path $xraySrc "xray.exe")) {
  Copy-Item (Join-Path $xraySrc "xray.exe") (Join-Path $xrayDst "xray.exe") -Force
  foreach ($extra in @("wintun.dll", "geoip.dat", "geosite.dat")) {
    $p = Join-Path $xraySrc $extra
    if (-not (Test-Path $p)) { $p = Join-Path $xraySrc "extract\$extra" }
    if (Test-Path $p) { Copy-Item $p (Join-Path $xrayDst $extra) -Force }
  }
  Write-Host "Bundled Xray into $xrayDst"
} else {
  Write-Warning "third_party/xray/xray.exe missing — connect will fail until it is present"
}

# Starlit ships Xray, not mihomo.
foreach ($dead in @("FlClashCore.exe", "FlClashHelperService.exe", "EnableLoopback.exe")) {
  $f = Join-Path $release $dead
  if (Test-Path $f) {
    Remove-Item $f -Force
    Write-Host "Removed $dead from Release"
  }
}

Write-Host "App built. Refresh packaging\StarlitConnect.iss file list if needed, then:"
Write-Host ('ISCC: "{0}" "{1}\packaging\StarlitConnect.iss"' -f $iscc, $root)
