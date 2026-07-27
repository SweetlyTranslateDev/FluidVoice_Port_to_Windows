# Builds Release portable output, then compiles the Inno Setup installer when ISCC is available.
# Falls back to portable zip only if Inno Setup is not installed.

param(
  [string]$RepoRoot = "",
  [string]$IssPath = "",
  [string]$IsccPath = ""
)

$ErrorActionPreference = "Stop"

if (-not $RepoRoot) {
  $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}

$Junction = "C:\dev\FluidVoice_Port_to_Windows"
if ((Test-Path $Junction) -and ($RepoRoot -match ";")) {
  $RepoRoot = $Junction
}

if ([string]::IsNullOrWhiteSpace($IssPath)) {
  $IssPath = Join-Path $RepoRoot "scripts\windows\FluidVoice.iss"
}

$portableScript = Join-Path $PSScriptRoot "build_portable.ps1"
& $portableScript -RepoRoot $RepoRoot

if ([string]::IsNullOrWhiteSpace($IsccPath)) {
  $candidates = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
  )
  foreach ($c in $candidates) {
    if (Test-Path $c) {
      $IsccPath = $c
      break
    }
  }
}

if (-not $IsccPath -or -not (Test-Path $IsccPath)) {
  Write-Warning "Inno Setup (ISCC.exe) not found. Portable zip was built; install Inno Setup 6 to produce a Setup.exe."
  exit 0
}

$FlutterApp = Join-Path $RepoRoot "flutter_app"
$releaseDir = Join-Path $FlutterApp "build\windows\x64\runner\Release"
$outDir = Join-Path $RepoRoot "dist"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Write-Host "Compiling installer with $IsccPath"
& $IsccPath `
  "/DReleaseDir=$releaseDir" `
  "/DOutputDir=$outDir" `
  $IssPath

Write-Host "Installer output directory: $outDir"
Get-ChildItem $outDir -Filter "FluidVoice-Windows-Setup-*.exe" | ForEach-Object {
  Write-Host ("Setup: " + $_.FullName)
}
