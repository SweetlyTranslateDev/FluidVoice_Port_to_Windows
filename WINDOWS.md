# FluidVoice for Windows (Flutter port)

Local Windows port living under `flutter_app/` + `native_plugins/`.  
macOS Swift sources at the repo root are **not** modified by this port.

## Quick start

1. Use a workspace path without `;` (junction), e.g. `C:\dev\FluidVoice_Port_to_Windows`
2. Install Flutter stable + VS 2022 “Desktop development with C++”
3. Run:

```powershell
cd C:\dev\FluidVoice_Port_to_Windows\flutter_app
flutter pub get
flutter run -d windows --release
```

Prefer **Release** for day-to-day STT speed testing (Debug ggml is much slower).

4. Hold the configured hotkey (default **F8**) to dictate; release to transcribe and insert into the focused app  
5. First run downloads the selected speech model (needs network once)

## What works (MVP)

| Feature | Notes |
|---------|--------|
| WASAPI mic capture | Device picker in Settings |
| Global PTT hotkey | Default: hold F8 (configurable in Settings) |
| Whisper STT | `tiny.en` / `base.en` via Models |
| Parakeet TDT STT | `parakeet-tdt-0.6b-v2-int8` (ONNX / sherpa-onnx) via Models |
| Text injection | SendInput → clipboard → UIA WM_CHAR |
| Overlay | Always-on-top click-through |
| Tray | Close hides; Quit from tray |
| Settings / history | AppData JSON |
| Launch at login | HKCU Run key |
| AI API key | Windows Credential Manager |
| Output modes | raw / enhance / rewrite / write |
| Local API | `127.0.0.1:47733` when enabled |
| Packaging | `scripts/windows/build_portable.ps1` |

## Models

- Whisper: ggml files under `%AppData%\…\FluidVoice\models\`
- Parakeet: extract `sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8` (~400MB) into a directory with `encoder*.onnx`, `decoder*.onnx`, `joiner*.onnx`, `tokens.txt`
- Native runtime DLLs (`sherpa-onnx-c-api.dll`, `onnxruntime*.dll`) ship beside the exe

## Portable Release package

```powershell
cd C:\dev\FluidVoice_Port_to_Windows
.\scripts\windows\build_portable.ps1
```

Produces `dist\FluidVoice-portable\` and a zip. No Visual Studio needed to run.

## Later (not MVP)

- Vosk backend  
- Meeting / file transcription  
- Installer / auto-updater  
- Full macOS feature parity  

See `docs/BUILDING_WINDOWS.md` and `docs/WINDOWS_PORT_PLAN.md`.
