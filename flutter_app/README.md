# FluidVoice Flutter (Windows)

Windows desktop app for FluidVoice. Built with Flutter + native C++ plugins.

The macOS Swift tree at the repository root is **reference only** and is not used by this Windows build.

## Core loop

**Hold hotkey (default F8) → WASAPI capture → Whisper or Parakeet → text inject + overlay → history**

Also: tray, settings, model picker (`tiny.en` / `base.en` / `parakeet-tdt-0.6b-v2-int8`), launch-at-login, Credential Manager API keys, AI output modes, local API, portable + installer packaging.

## Run

Use a path **without `;`** (junction: `C:\dev\FluidVoice_Port_to_Windows`). Prefer **Release** for STT speed:

```powershell
cd C:\dev\FluidVoice_Port_to_Windows\flutter_app
flutter pub get
flutter run -d windows --release
```

On Home, confirm the status line shows your model (`backend:Parakeet ONNX` or `backend:Whisper`).

## Package

```powershell
cd C:\dev\FluidVoice_Port_to_Windows
.\scripts\windows\build_portable.ps1
.\scripts\windows\build_installer.ps1
```

Outputs under `dist\` (portable folder/zip + Setup.exe when Inno Setup 6 is installed).

## Docs

- [Root README](../README.md)
- [Windows quick start](../WINDOWS.md)
- [Building Windows](../docs/BUILDING_WINDOWS.md)
- [Architecture](../docs/ARCHITECTURE.md)
- [Windows port plan](../docs/WINDOWS_PORT_PLAN.md)
- [Plugin API](../docs/PLUGIN_API.md)
- [Local API](../docs/LOCAL_API.md)
- [ONNX / Parakeet](../native_plugins/speech_runtime/onnx_runtime/README.md)
