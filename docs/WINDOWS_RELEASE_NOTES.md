# FluidVoice for Windows — Release notes (pre-parity)

**Status: partial Windows port (MVP), not full macOS feature parity.**

This build is a Flutter + native C++ Windows app. It is **not** the macOS Swift FluidVoice product packaged for Windows. Upstream macOS-only features (CoreML, Fluid Intelligence, notch UI, Apple Speech, etc.) are out of scope here.

Use this document as the GitHub Release description for installer / portable artifacts.

---

## Artifacts

| File | Purpose |
|------|---------|
| `FluidVoice-Windows-Setup-1.0.0.exe` | Per-user Inno Setup installer (x64) |
| `FluidVoice-portable.zip` | Portable folder — unzip and run `fluidvoice_app.exe` |

Speech models are **not** bundled. On first use the app downloads the selected model into AppData (network required once). Prefer the Release build for usable STT speed.

---

## Ported (included in this release)

### Dictation core
- Global **push-to-talk** hotkey (default **F8**; configurable in Settings)
- **WASAPI** microphone capture + device picker
- On-device STT via unified `speech_runtime`:
  - **Whisper** `tiny.en` / `base.en` (ggml / whisper.cpp)
  - **Parakeet TDT** `parakeet-tdt-0.6b-v2-int8` (English ONNX via sherpa-onnx)
- Text injection into the focused app (SendInput → clipboard → UIA fallback)
- Always-on-top overlay while listening / processing
- System tray (close hides to tray; Quit from tray menu)

### App shell
- Home / Models / History / Settings UI (dark Windows shell)
- Transcript history with retention options
- Launch at login
- Always-on-top + optional acrylic window chrome
- Optional cloud AI output modes: raw / enhance / rewrite / write (API key in Windows Credential Manager)
- Optional local loopback HTTP API (`127.0.0.1:47733`)

### Packaging
- Portable zip and Setup.exe (this release)

---

## Not ported yet (do not expect these)

Compared with full macOS FluidVoice, this Windows build does **not** include:

| Area | Notes |
|------|--------|
| Fluid Intelligence | Private on-device AI runtime (macOS) |
| Apple Speech / CoreML | Apple-only |
| Parakeet Flash / streaming live STT | Windows path is **batch PTT** (hold → release → transcribe) |
| Nemotron / Cohere / Parakeet v3 multilingual catalog | Not offered in Models UI |
| Vosk backend | Planned later under `speech_runtime` |
| Command Mode | macOS automation / AppleScript-style control |
| Write Mode (macOS parity) | Partial cloud “write/rewrite” modes exist; not full macOS Write Mode |
| Meeting / file transcription | Not implemented |
| Per-app prompt routing | Not implemented |
| Audio history export / ZIP | Not implemented |
| Notch-aware overlay | macOS only |
| Auto-updater / beta channel | Not implemented |
| HomeBrew / macOS permissions flow | N/A on Windows |
| Full UI / theming parity | Windows shell is a parallel UI |

---

## Known limitations

- First **Parakeet** download/load is large (~400MB) and can take a minute; Home status shows the active model (`backend:Parakeet ONNX` vs `backend:Whisper`).
- STT quality and latency depend on CPU and chosen model; Debug builds are much slower than Release.
- Text injection reliability varies by target app (some Electron/UWP apps are harder).
- Bluetooth headset / device-disconnect recovery not fully verified.
- This is an **MVP port** for day-to-day dictation testing, not a 1:1 feature match with macOS 1.6.x.

---

## Quick start after install

1. Run FluidVoice (Start Menu or portable `fluidvoice_app.exe`).
2. Allow microphone access when Windows prompts.
3. Open **Models** → choose Whisper or Parakeet → wait for download.
4. Return to **Home** — confirm status shows your model.
5. Hold the hotkey, speak, release → text inserts into the focused app.

---

## Build / docs

- Quick start: `WINDOWS.md`
- Toolchain & packaging: `docs/BUILDING_WINDOWS.md`
- Port plan / checklist: `docs/WINDOWS_PORT_PLAN.md`
- App overview: root `README.md`
