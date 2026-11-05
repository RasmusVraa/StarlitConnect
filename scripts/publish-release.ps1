# Create/update a GitHub Release for StarlitConnect Windows installer.
# Requires: gh auth, built dist\StarlitConnect-*-windows-amd64-setup.exe
#
# Usage:
#   .\scripts\publish-release.ps1
#   .\scripts\publish-release.ps1 -Tag v1.0.2 -Notes "fix TUN"

param(
  [string]$Tag = "",
  [string]$Notes = "StarlitConnect Windows installer"
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

$pubspec = Get-Content (Join-Path $root "pubspec.yaml") -Raw
if ($pubspec -notmatch 'version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
  throw "Cannot parse version from pubspec.yaml"
}
$version = $Matches[1]
if (-not $Tag) { $Tag = "v$version" }

$setup = Get-ChildItem (Join-Path $root "dist") -Filter "StarlitConnect-$version-windows-amd64-setup.exe" |
  Select-Object -First 1
if (-not $setup) {
  throw "Missing dist\StarlitConnect-$version-windows-amd64-setup.exe. Build first."
}

$assetName = $setup.Name
$sumsPath = Join-Path $root "dist\SHA256SUMS"
$hash = (Get-FileHash -LiteralPath $setup.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
# Format expected by lib/common/app_update.dart releaseChecksum()
Set-Content -LiteralPath $sumsPath -Value "$hash  $assetName" -Encoding ascii

Write-Host "Tag:    $Tag"
Write-Host "Asset:  $assetName"
Write-Host "SHA256: $hash"

gh release view $Tag -R RasmusVraa/StarlitConnect 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
  Write-Host "Release $Tag exists - uploading/replacing assets..."
  gh release upload $Tag -R RasmusVraa/StarlitConnect $setup.FullName $sumsPath --clobber
} else {
  gh release create $Tag -R RasmusVraa/StarlitConnect $setup.FullName $sumsPath --title "StarlitConnect $version" --notes $Notes
}

Write-Host "Done: https://github.com/RasmusVraa/StarlitConnect/releases/tag/$Tag"

