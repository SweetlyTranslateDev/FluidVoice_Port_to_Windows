# Smoke-test fluidvoice_speech.dll (Whisper prepare/transcribe + Parakeet prepare).
# Run from a path without ';'. Uses Release DLLs from flutter build windows --release.

param(
  [string]$ReleaseDir = "",
  [switch]$SkipParakeetDownload
)

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Junction = "C:\dev\FluidVoice_Port_to_Windows"
if ((Test-Path $Junction) -and ($RepoRoot -match ";")) {
  $RepoRoot = $Junction
}

if (-not $ReleaseDir) {
  $ReleaseDir = Join-Path $RepoRoot "flutter_app\build\windows\x64\runner\Release"
}

$Dll = Join-Path $ReleaseDir "fluidvoice_speech.dll"
if (-not (Test-Path $Dll)) {
  throw "Missing $Dll - run flutter build windows --release first"
}

foreach ($name in @(
    "sherpa-onnx-c-api.dll",
    "onnxruntime.dll",
    "onnxruntime_providers_shared.dll"
  )) {
  $p = Join-Path $ReleaseDir $name
  if (-not (Test-Path $p)) {
    throw "Missing runtime DLL: $name"
  }
}

$Work = Join-Path $env:TEMP "fluidvoice_speech_smoke"
New-Item -ItemType Directory -Force -Path $Work | Out-Null

$WhisperUrl = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin"
$WhisperPath = Join-Path $Work "ggml-tiny.en.bin"
if (-not (Test-Path $WhisperPath) -or ((Get-Item $WhisperPath).Length -lt 1000000)) {
  Write-Host "Downloading Whisper tiny.en..."
  Invoke-WebRequest -Uri $WhisperUrl -OutFile $WhisperPath
}

$ParakeetDir = Join-Path $Work "parakeet-tdt-0.6b-v2-int8"
$ParakeetArchive = Join-Path $Work "sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8.tar.bz2"
$ParakeetUrl = "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8.tar.bz2"

function Test-ParakeetReady([string]$Dir) {
  if (-not (Test-Path (Join-Path $Dir "tokens.txt"))) { return $false }
  $enc = Get-ChildItem $Dir -Filter "encoder*.onnx" -ErrorAction SilentlyContinue
  $dec = Get-ChildItem $Dir -Filter "decoder*.onnx" -ErrorAction SilentlyContinue
  $join = Get-ChildItem $Dir -Filter "joiner*.onnx" -ErrorAction SilentlyContinue
  return ($null -ne $enc -and $null -ne $dec -and $null -ne $join)
}

if (-not (Test-ParakeetReady $ParakeetDir)) {
  if ($SkipParakeetDownload) {
    Write-Host "SKIP: Parakeet model not present (-SkipParakeetDownload)"
  } else {
    if (-not (Test-Path $ParakeetArchive) -or ((Get-Item $ParakeetArchive).Length -lt 1000000)) {
      Write-Host "Downloading Parakeet int8 model (~400MB)..."
      Invoke-WebRequest -Uri $ParakeetUrl -OutFile $ParakeetArchive
    }
    Write-Host "Extracting Parakeet archive..."
    if (Test-Path $ParakeetDir) { Remove-Item -Recurse -Force $ParakeetDir }
    New-Item -ItemType Directory -Force -Path $ParakeetDir | Out-Null
    & tar -xjf $ParakeetArchive -C $Work
    $extracted = Get-ChildItem $Work -Directory | Where-Object {
      $_.Name -like "sherpa-onnx-nemo-parakeet*"
    } | Select-Object -First 1
    if (-not $extracted) {
      throw "Parakeet extract folder not found under $Work"
    }
    Copy-Item -Path (Join-Path $extracted.FullName "*") -Destination $ParakeetDir -Recurse -Force
    if (-not (Test-ParakeetReady $ParakeetDir)) {
      throw "Parakeet files missing after extract"
    }
  }
}

$Cs = @'
using System;
using System.Runtime.InteropServices;

public static class FvSpeechSmoke {
  [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
  public static extern bool SetDllDirectory(string lpPathName);

  [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
  public static extern IntPtr LoadLibrary(string lpFileName);

  [DllImport("fluidvoice_speech.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
  public static extern int fv_speech_init();

  [DllImport("fluidvoice_speech.dll", CallingConvention = CallingConvention.Cdecl)]
  public static extern void fv_speech_shutdown();

  [DllImport("fluidvoice_speech.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
  public static extern int fv_speech_prepare(string model_path);

  [DllImport("fluidvoice_speech.dll", CallingConvention = CallingConvention.Cdecl)]
  public static extern int fv_speech_transcribe(float[] samples, int sample_count, int sample_rate, out IntPtr out_text);

  [DllImport("fluidvoice_speech.dll", CallingConvention = CallingConvention.Cdecl)]
  public static extern void fv_speech_free(IntPtr p);

  [DllImport("fluidvoice_speech.dll", CallingConvention = CallingConvention.Cdecl)]
  public static extern IntPtr fv_speech_last_error();

  public static string LastError() {
    var p = fv_speech_last_error();
    return p == IntPtr.Zero ? "" : Marshal.PtrToStringAnsi(p) ?? "";
  }

  public static string TranscribeSilence() {
    var samples = new float[8000];
    IntPtr textPtr;
    int rc = fv_speech_transcribe(samples, samples.Length, 16000, out textPtr);
    if (rc != 0) {
      throw new Exception("transcribe failed: " + LastError());
    }
    try {
      return textPtr == IntPtr.Zero ? "" : (Marshal.PtrToStringAnsi(textPtr) ?? "");
    } finally {
      if (textPtr != IntPtr.Zero) fv_speech_free(textPtr);
    }
  }
}
'@

Add-Type -TypeDefinition $Cs -ErrorAction Stop
[void][FvSpeechSmoke]::SetDllDirectory($ReleaseDir)
$loaded = [FvSpeechSmoke]::LoadLibrary((Join-Path $ReleaseDir "fluidvoice_speech.dll"))
if ($loaded -eq [IntPtr]::Zero) {
  throw "LoadLibrary failed for fluidvoice_speech.dll (Win32=$([Runtime.InteropServices.Marshal]::GetLastWin32Error()))"
}

Write-Host "fv_speech_init..."
$rc = [FvSpeechSmoke]::fv_speech_init()
if ($rc -ne 0) { throw "init failed: $([FvSpeechSmoke]::LastError())" }

Write-Host "Whisper prepare: $WhisperPath"
$rc = [FvSpeechSmoke]::fv_speech_prepare($WhisperPath)
if ($rc -ne 0) { throw "whisper prepare failed: $([FvSpeechSmoke]::LastError())" }

$wText = [FvSpeechSmoke]::TranscribeSilence()
Write-Host "Whisper transcribe(silence) ok (text='$wText')"

if (Test-ParakeetReady $ParakeetDir) {
  Write-Host "Parakeet prepare: $ParakeetDir"
  $rc = [FvSpeechSmoke]::fv_speech_prepare($ParakeetDir)
  if ($rc -ne 0) { throw "parakeet prepare failed: $([FvSpeechSmoke]::LastError())" }

  $pText = [FvSpeechSmoke]::TranscribeSilence()
  Write-Host "Parakeet transcribe(silence) ok (text='$pText')"
}

[FvSpeechSmoke]::fv_speech_shutdown()
Write-Host "SMOKE OK"

