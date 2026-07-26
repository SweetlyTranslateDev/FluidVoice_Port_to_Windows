# Builds a portable FluidVoice zip from a Flutter Windows Release tree.
# Run from anywhere. Prefer the junction path without ';' for Flutter builds.

param(
  [string]$FlutterAppDir = "C:\dev\FluidVoice_Port_to_Windows\flutter_app",
  [string]$OutDir = ""
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $FlutterAppDir)) {
  throw "Flutter app dir not found: $FlutterAppDir"
}

if ([string]::IsNullOrWhiteSpace($OutDir)) {
  $OutDir = Join-Path $FlutterAppDir "dist"
}

Write-Host "Building Flutter Windows Release..."
Set-Location $FlutterAppDir
flutter build windows --release

$releaseDir = Join-Path $FlutterAppDir "build\windows\x64\runner\Release"
if (-not (Test-Path (Join-Path $releaseDir "fluidvoice_app.exe"))) {
  throw "Release output missing: $releaseDir"
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd"
$zipPath = Join-Path $OutDir "FluidVoice-Windows-portable-$stamp.zip"

if (Test-Path $zipPath) {
  Remove-Item -Force $zipPath
}

Write-Host "Creating portable zip: $zipPath"
Compress-Archive -Path (Join-Path $releaseDir "*") -DestinationPath $zipPath -Force

Write-Host "Done."
Write-Host "Portable archive: $zipPath"
Write-Host "Required DLLs (wasapi/hotkeys/speech/inject) are included beside the exe."
