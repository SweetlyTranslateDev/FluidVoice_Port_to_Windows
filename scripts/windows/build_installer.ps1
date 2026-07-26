# Builds Release, then compiles the Inno Setup installer when ISCC is available.
# Falls back to portable zip only if Inno Setup is not installed.

param(
  [string]$FlutterAppDir = "C:\dev\FluidVoice_Port_to_Windows\flutter_app",
  [string]$IssPath = "",
  [string]$IsccPath = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if ([string]::IsNullOrWhiteSpace($IssPath)) {
  $IssPath = Join-Path $repoRoot "scripts\windows\FluidVoice.iss"
}

$portableScript = Join-Path $PSScriptRoot "build_portable.ps1"
& $portableScript -FlutterAppDir $FlutterAppDir

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

$releaseDir = Join-Path $FlutterAppDir "build\windows\x64\runner\Release"
$outDir = Join-Path $FlutterAppDir "dist"

Write-Host "Compiling installer with $IsccPath"
& $IsccPath `
  "/DReleaseDir=$releaseDir" `
  "/DOutputDir=$outDir" `
  $IssPath

Write-Host "Installer output directory: $outDir"
