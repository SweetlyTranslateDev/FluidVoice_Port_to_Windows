# FluidVoice Windows Architecture

This document describes the target architecture for the **parallel Flutter Windows port** of FluidVoice. The existing macOS Swift application remains the reference implementation and must not be broken.

## Principles

1. **Parallel port** — Add `flutter_app/`, `native_plugins/`, and `docs/` alongside the existing macOS tree. Do not delete or rewrite the Swift project.
2. **WHAT vs HOW** — Flutter/Dart defines what the product needs. Windows C++ plugins implement how OS/audio/inference work.
3. **No business logic in C++** — Dictation flow, settings, history, AI routing, and hotkey state machine live in Dart (`flutter_app/lib/core/`).
4. **`lib/core` is Dart core** — Not a native C++ core.
5. **Unified speech facade** — The app calls `speechEngine.transcribe(...)`, never a per-model plugin API.
6. **GPLv3** — Preserve attribution, licensing, and history.

## Layer diagram

```text
┌─────────────────────────────────────────────────────────────┐
│  flutter_app/lib/features  (UI: settings, history, etc.)    │
├─────────────────────────────────────────────────────────────┤
│  flutter_app/lib/core                                         │
│    DictationController, HotkeyStateMachine, managers,         │
│    interfaces (AudioCapture, SpeechEngine, AIProvider, ...) │
├──────────────────────┬──────────────────────────────────────┤
│  Dart FFI            │  MethodChannels                        │
│  (high-rate paths)   │  (desktop host / settings bridge)      │
├──────────────────────┼──────────────────────────────────────┤
│  wasapi_audio        │  overlay_window / tray                 │
│  speech_runtime      │  window management                     │
│  (hooks / UIA FFI)   │                                        │
└──────────────────────┴──────────────────────────────────────┘
         native_plugins/ (C++ HOW only)
```

## macOS reference product loop

```text
global hotkey → mic capture → 16 kHz mono PCM → TranscriptionProvider
  → punctuation / dictionary / AI → clipboard or focused-app injection
  → history / overlay / tray
```

Key reference paths (do not modify for the Windows port unless explicitly required):

| Layer | Path |
|--------|------|
| Entry | `Sources/Fluid/fluidApp.swift`, `AppDelegate.swift`, `ContentView.swift` |
| Orchestration | `Sources/Fluid/Services/ASRService.swift`, `AppServices.swift` |
| STT contract | `Sources/Fluid/Services/TranscriptionProvider.swift` |
| Hotkeys | `Sources/Fluid/Services/GlobalHotkeyManager.swift` |
| Typing | `Sources/Fluid/Services/TypingService.swift` |
| Persistence | `Sources/Fluid/Persistence/` |
| CoreAudio C | `Sources/CoreAudioCaptureSupport/` |

## Flutter layout

```text
flutter_app/lib/
  app/           # routes, theme, app.dart
  features/      # dictation, settings, history, models, onboarding
  core/
    services/    # DictationController, HistoryManager, SettingsManager, ...
    models/
    storage/
    interfaces/  # AudioCapture, SpeechEngine, AIProvider, TextInjector, ...
  main.dart
```

### Core responsibilities

| Type | Responsibility |
|------|----------------|
| `DictationController` | Orchestrates capture → speech → post-process → inject |
| `HotkeyStateMachine` | PTT / toggle / hold semantics (Dart) |
| `SettingsManager` | User preferences persistence |
| `HistoryManager` | Transcription history |
| `AIProvider` | OpenAI-compatible enhancement (Dart HTTP) |
| `SpeechEngine` | Unified STT facade over `speech_runtime` |
| `AudioCapture` | Stream of PCM chunks from WASAPI plugin |
| `TextInjector` | Focused-app insertion |
| `HotkeySource` | Native key events only |
| `TrayHost` / overlay | Desktop host via MethodChannel |

## Native plugins

```text
native_plugins/
  plugin_api/         # shared FFI + channel contracts
  wasapi_audio/       # WASAPI capture (FFI)
  global_hotkeys/     # hooks / RegisterHotKey
  text_injection/     # UIA + SendInput + clipboard fallback
  overlay_window/     # frameless always-on-top host
  speech_runtime/     # ONE facade
    whisper_cpp/
    onnx_runtime/
    vosk/
    future_models/
```

## IPC rules

| Transport | Use for | Forbidden for |
|-----------|---------|----------------|
| **Dart FFI** | WASAPI PCM, speech_runtime / whisper.cpp, other high-rate paths | — |
| **MethodChannels** | settings bridge, tray, window management | **audio streaming** |

Audio must never cross MethodChannels.

## WASAPI pipeline (required)

```text
WASAPI Capture Thread
        ↓
Lock-free Ring Buffer
        ↓
Audio Worker Thread  (format / resample / mono 16 kHz)
        ↓
Dart Stream via FFI
```

Do **not** invoke Dart from the WASAPI callback. GC pauses will eventually cause drops or jitter.

## Speech runtime

- App-facing API: `SpeechEngine` in Dart.
- Backends live under `native_plugins/speech_runtime/` only.
- Priority: portable OSS models → whisper.cpp → Parakeet/ONNX → Vosk.
- Do not hard-code a single model.
- Do not expose `whisperPlugin.transcribe` style APIs to features/UI.

## What stays out of C++

- Dictation session state
- Prompt / AI routing
- Settings and history schemas
- Hotkey mode logic (push-to-talk vs toggle)
- Spoken punctuation and literal formatting
- Local HTTP API business routes (transport may be Dart `HttpServer`)

C++ may only: capture audio, run inference, emit input events, inject text, manage OS windows/tray.

## Related docs

- [WINDOWS_PORT_PLAN.md](WINDOWS_PORT_PLAN.md) — migration phases and feature mapping
- [PLUGIN_API.md](PLUGIN_API.md) — interface and transport contracts
- [BUILDING_WINDOWS.md](BUILDING_WINDOWS.md) — build instructions
- [CONTRIBUTING.md](CONTRIBUTING.md) — contribution rules for the parallel port
