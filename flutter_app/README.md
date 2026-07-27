# FluidVoice Flutter (Windows)

Parallel Windows app for FluidVoice. The macOS Swift tree at the repository root stays untouched.

## Status

Core loop:

**Hold hotkey (default F8) → WASAPI capture → Whisper or Parakeet → text inject + overlay → history**

Also included: tray, settings persistence, model picker (`tiny.en` / `base.en` / `parakeet-tdt-0.6b-v2-int8`), launch-at-login, Credential Manager API keys, AI output modes, loopback Local API, portable packaging.

## Run

Prefer a path **without `;`** (junction example: `C:\dev\FluidVoice_Port_to_Windows`).

For usable STT speed, use **Release**:

```powershell
cd C:\dev\FluidVoice_Port_to_Windows\flutter_app
flutter pub get
flutter run -d windows --release
```

Debug builds work but Whisper/Parakeet will feel much slower.

## Models

Select in **Models**:

| Id | Backend |
|----|---------|
| `tiny.en` / `base.en` | whisper.cpp (ggml) |
| `parakeet-tdt-0.6b-v2-int8` | sherpa-onnx Parakeet TDT (English int8 ONNX) |

Large Parakeet download shows progress in the Models page; files cache under AppData.

## Package

```powershell
cd C:\dev\FluidVoice_Port_to_Windows
.\scripts\windows\build_portable.ps1
```

Optional installer script (if present): `.\scripts\windows\build_installer.ps1`

## Docs

- [Architecture](../docs/ARCHITECTURE.md)
- [Windows port plan](../docs/WINDOWS_PORT_PLAN.md)
- [Plugin API](../docs/PLUGIN_API.md)
- [Building Windows](../docs/BUILDING_WINDOWS.md)
- [Local API](../docs/LOCAL_API.md)
- [Windows quick start](../WINDOWS.md)
- [Contributing](../docs/CONTRIBUTING.md)
- [ONNX / Parakeet notes](../native_plugins/speech_runtime/onnx_runtime/README.md)
