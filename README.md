# FluidVoice for Windows

Local **Windows** voice-to-text dictation app. Hold a global hotkey, speak, release — text is transcribed on-device and inserted into the focused application.

This repository is a **Flutter + native C++ Windows port**. The original FluidVoice macOS app (Swift) remains in-tree as reference only and is **not** what you build or run on Windows.

| Layer | Tech |
|-------|------|
| UI / app shell | Flutter (Windows desktop) under `flutter_app/` |
| Mic, hotkeys, STT, inject, tray, overlay | Native plugins under `native_plugins/` |
| Speech | whisper.cpp (ggml) and Parakeet TDT (ONNX via sherpa-onnx) behind one `speech_runtime` facade |

---

## What works today

- **Push-to-talk** global hotkey (default **F8**, configurable in Settings)
- **WASAPI** microphone capture with device picker
- **Whisper** `tiny.en` / `base.en` (ggml)
- **Parakeet TDT** `parakeet-tdt-0.6b-v2-int8` (English ONNX, offline batch)
- Text injection into other apps (SendInput → clipboard → UIA)
- Live overlay, system tray (close hides; Quit from tray)
- Settings & transcript history (AppData JSON)
- Launch at login, always-on-top, optional acrylic
- Optional cloud AI output modes (raw / enhance / rewrite / write) via API key in Windows Credential Manager
- Optional local loopback API on `127.0.0.1:47733`
- Portable zip and Inno Setup installer

Not in this Windows slice yet: Vosk, streaming Parakeet Flash, meeting/file STT, full macOS feature parity.

---

## Quick start (run from source)

1. Install **Flutter stable** and **Visual Studio 2022** with “Desktop development with C++”.
2. Use a workspace path **without `;`**. If needed, create a junction, e.g. `C:\dev\FluidVoice_Port_to_Windows`.
3. Prefer **Release** for usable STT speed:

```powershell
cd C:\dev\FluidVoice_Port_to_Windows\flutter_app
flutter pub get
flutter run -d windows --release
```

4. Hold the hotkey to dictate; release to transcribe and inject.
5. On first use, the selected model downloads (network once). Parakeet is ~400MB.

On **Home**, the status line shows the active model, e.g. `model:parakeet-tdt-0.6b-v2-int8 · backend:Parakeet ONNX`.

---

## Install packages

From the repo root (junction path recommended):

```powershell
cd C:\dev\FluidVoice_Port_to_Windows
.\scripts\windows\build_portable.ps1
.\scripts\windows\build_installer.ps1
```

| Output | Location |
|--------|----------|
| Portable folder | `dist\FluidVoice-portable\` |
| Portable zip | `dist\FluidVoice-portable.zip` |
| Setup exe | `dist\FluidVoice-Windows-Setup-1.0.0.exe` (needs [Inno Setup 6](https://jrsoftware.org/isinfo.php)) |

Runtime DLLs (`fluidvoice_*.dll`, `sherpa-onnx-c-api.dll`, `onnxruntime*.dll`) ship beside the exe. Speech models are **not** bundled; they download into AppData on first use.

---

## Models

Select under **Models** in the app:

| Id | Backend | Notes |
|----|---------|--------|
| `tiny.en` | Whisper (ggml) | Fast English default |
| `base.en` | Whisper (ggml) | Higher quality English |
| `parakeet-tdt-0.6b-v2-int8` | Parakeet via sherpa-onnx | English ONNX int8, larger download |

After changing models, return to **Home** so the app reloads the selection. Status text shows which backend is loaded.

---

## Repository layout

```text
flutter_app/           # Flutter Windows application
native_plugins/        # C++ plugins + shared plugin API headers
scripts/windows/       # Portable + installer + smoke tests
docs/                  # Architecture, build, port plan
WINDOWS.md             # Short Windows quick start
Sources/ …             # Upstream macOS Swift (reference only; not built here)
```

More detail:

- [WINDOWS.md](WINDOWS.md) — Windows quick start
- [flutter_app/README.md](flutter_app/README.md) — Flutter app notes
- [docs/BUILDING_WINDOWS.md](docs/BUILDING_WINDOWS.md) — toolchain and packaging
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — system design
- [docs/WINDOWS_PORT_PLAN.md](docs/WINDOWS_PORT_PLAN.md) — port status
- [native_plugins/speech_runtime/onnx_runtime/README.md](native_plugins/speech_runtime/onnx_runtime/README.md) — Parakeet / ONNX notes

---

## Requirements

- Windows 10 or 11 (x64)
- Flutter stable + VS 2022 C++ desktop workload (to build)
- Microphone
- ~100MB+ disk for Whisper tiny, or ~400MB+ for Parakeet
- Network on first model download

---

## Privacy

Dictation STT runs **on-device**. Audio and transcripts stay local unless you enable a cloud AI output mode and provide an API key.

---

## License

This project is licensed under the [GNU General Public License, Version 3.0 (GPLv3)](LICENSE).

The macOS Swift tree retained in this repo is upstream FluidVoice reference material; the Windows product path is `flutter_app/` + `native_plugins/`.
