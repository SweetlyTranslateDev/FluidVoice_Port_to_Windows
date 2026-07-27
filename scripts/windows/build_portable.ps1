# Builds a portable Release folder for FluidVoice Windows (no Visual Studio required to run).
# Prefer a path without ';' (junction), e.g. C:\dev\FluidVoice_Port_to_Windows

param(
  [string]$RepoRoot = "",
  [string]$OutDir = ""
)

$ErrorActionPreference = "Stop"

if (-not $RepoRoot) {
  $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}

# Prefer junction path when the real path contains ';' (breaks Flutter/CMake).
$Junction = "C:\dev\FluidVoice_Port_to_Windows"
if ((Test-Path $Junction) -and ($RepoRoot -match ";")) {
  $RepoRoot = $Junction
}

$FlutterApp = Join-Path $RepoRoot "flutter_app"
if (-not (Test-Path (Join-Path $FlutterApp "pubspec.yaml"))) {
  throw "flutter_app not found under $RepoRoot"
}

if (-not $OutDir) {
  $OutDir = Join-Path $RepoRoot "dist\FluidVoice-portable"
}

Write-Host "RepoRoot: $RepoRoot"
Write-Host "Building Flutter Windows Release..."
Push-Location $FlutterApp
try {
  flutter pub get
  flutter build windows --release
}
finally {
  Pop-Location
}

$ReleaseDir = Join-Path $FlutterApp "build\windows\x64\runner\Release"
if (-not (Test-Path (Join-Path $ReleaseDir "fluidvoice_app.exe"))) {
  throw "Release output missing at $ReleaseDir"
}

if (Test-Path $OutDir) {
  Remove-Item -Recurse -Force $OutDir
}
New-Item -ItemType Directory -Path $OutDir | Out-Null

Write-Host "Copying Release bundle to $OutDir"
Copy-Item -Path (Join-Path $ReleaseDir "*") -Destination $OutDir -Recurse -Force

$Required = @(
  "fluidvoice_app.exe",
  "flutter_windows.dll",
  "fluidvoice_speech.dll",
  "sherpa-onnx-c-api.dll",
  "onnxruntime.dll",
  "onnxruntime_providers_shared.dll"
)
foreach ($name in $Required) {
  $path = Join-Path $OutDir $name
  if (-not (Test-Path $path)) {
    throw "Missing required file in portable output: $name"
  }
}

$ZipPath = "$OutDir.zip"
if (Test-Path $ZipPath) {
  Remove-Item -Force $ZipPath
}
Compress-Archive -Path (Join-Path $OutDir "*") -DestinationPath $ZipPath -Force

Write-Host "Portable folder: $OutDir"
Write-Host "Zip: $ZipPath"
Write-Host "Done. Models download on first run into AppData."
