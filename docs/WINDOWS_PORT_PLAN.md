# FluidVoice Windows Port Plan

Parallel Flutter Windows port of FluidVoice. The macOS Swift application is the reference implementation and must remain intact.

## Goals

- Fully functional Windows 10/11 dictation app
- Flutter desktop UI
- Native Windows C++ integrations where required
- Preserve GPLv3 attribution and history
- Rebuild equivalent behavior with correct Windows technologies (not a line-by-line Swift conversion)

## Governing rules

1. Do not delete, rewrite, or break the macOS project.
2. Create Flutter/C++ Windows code **alongside** existing sources.
3. Leave the current macOS tree at repository root (`Sources/Fluid`, `Fluid.xcodeproj`, `Package.swift`). Do not require a move into `macos/` for Phase 0.
4. Before large changes, explain files to create or modify.
5. Prefer native Windows APIs. No Electron. No Qt.
6. No business logic in C++.
7. Define Dart interfaces before implementing Win32 APIs.

## Current architecture (macOS reference)

FluidVoice today is a native **macOS 15+** SwiftUI application built with Xcode and Swift Package Manager. There is no Flutter or Windows project in the historical macOS tree; the Windows port adds new directories described below.

### Product loop

```text
global hotkey → mic capture → 16 kHz mono PCM → TranscriptionProvider
  → punctuation / dictionary / AI → clipboard or focused-app injection
  → history / overlay / tray
```

### Layers

| Layer | Path | Role |
|--------|------|------|
| UI | `Sources/Fluid/UI`, `Views`, `Theme` | Settings, onboarding, history, overlays |
| Services | `Sources/Fluid/Services` | ASR, hotkeys, typing, AI, tray, meeting STT, local API |
| Persistence | `Sources/Fluid/Persistence` | Settings, history, audio, keychain, backup |
| Networking | `Sources/Fluid/Networking` | AI providers, model downloads |
| Models | `Sources/Fluid/Models` | Hotkeys and shared types |
| Native C | `Sources/CoreAudioCaptureSupport` | CoreAudio IO + PCM ring buffer |

### Important reference files

| File | Role |
|------|------|
| `Sources/Fluid/fluidApp.swift` | SwiftUI `@main` entry |
| `Sources/Fluid/AppDelegate.swift` | Lifecycle, analytics, updates, local API |
| `Sources/Fluid/ContentView.swift` | Workflow coordinator |
| `Sources/Fluid/Services/AppServices.swift` | Lazy service container |
| `Sources/Fluid/Services/ASRService.swift` | Capture + provider orchestration |
| `Sources/Fluid/Services/TranscriptionProvider.swift` | STT provider contract |
| `Sources/Fluid/Services/GlobalHotkeyManager.swift` | CGEventTap hotkeys |
| `Sources/Fluid/Services/TypingService.swift` | Accessibility text insertion |
| `Sources/Fluid/Services/WhisperProvider.swift` | Whisper / TranscribeCpp |
| `Sources/Fluid/Networking/AIProvider.swift` | OpenAI-compatible AI |
| `Sources/Fluid/Persistence/SettingsStore.swift` | Settings (large, mixed with AppKit) |

## Build system (macOS reference)

| Piece | Detail |
|--------|--------|
| IDE project | `Fluid.xcodeproj` (scheme `Fluid`, app target `FluidVoice`) |
| SPM | `Package.swift` — Swift 5.9, `.macOS("15.0")` |
| Script | `build.sh` |
| Lint | `.swiftlint.yml` |
| CI | macOS Xcode workflows under `.github/workflows/` |

### SPM dependencies (`Package.swift`)

| Package | Purpose |
|---------|---------|
| FluidAudio | CoreML Parakeet / Nemotron / Cohere ASR (Apple-centric) |
| TranscribeCpp (`transcribe-cpp-swift` 0.1.2) | Whisper GGUF — best Windows reuse candidate |
| DynamicNotchKit | MacBook notch overlays |
| AppUpdater + PromiseKit | Update flow |
| PostHog | Analytics packaging |

**Not portable to Windows as-is:** FluidAudio/CoreML, Apple Speech, DynamicNotchKit, MediaRemote, Keychain, CGEventTap, CoreAudio.

**License:** GPLv3 (`LICENSE`). Fluid Intelligence local AI runtime is private / out of repository and out of Windows MVP scope.

## Feature mapping (macOS → Windows → status)

| macOS implementation | Windows replacement | Status |
|----------------------|---------------------|--------|
| SwiftUI / AppKit | Flutter desktop UI | planned |
| CoreAudio / AVAudioEngine | WASAPI (`IAudioClient` / `IAudioCaptureClient`) via FFI | done |
| CGEventTap hotkeys | Low-level hooks and/or `RegisterHotKey`; PTT down/up in Dart state machine | done |
| Accessibility text insert | SendInput → clipboard restore → UIA WM_CHAR; UIA selection read | done |
| NSPanel / DynamicNotchKit overlay | Win32 layered always-on-top overlay (MethodChannel) | done |
| NSStatusItem menu bar | Tray via MethodChannel / Win32 notify icon | done |
| Apple Speech / CoreML / FluidAudio | Drop on Windows; use `speech_runtime` backends | planned |
| Whisper / TranscribeCpp | `speech_runtime` → whisper.cpp (FFI) | done |
| Parakeet-class models | `speech_runtime` → ONNX where possible (later) | planned |
| Keychain | Windows Credential Manager / DPAPI | planned |
| SMAppService launch-at-login | Startup folder / Run key / Task Scheduler | planned |
| NWListener local API | Dart `HttpServer` / shelf | planned |
| AppUpdater | Windows installer + portable build (later) | planned |
| MediaRemote | SMTC / WinRT media (later) | planned |

Update the **Status** column as work lands (`planned` → `in progress` → `done`).

## Reusable logic (port to Dart `lib/core`)

Port **behavior and schemas**, not Swift binaries:

- `TranscriptionProvider` contract → `SpeechEngine` / transcription interfaces
- Spoken punctuation / literal formatting (`ASRService+SpokenPunctuationFormatting`, `+DictationLiteralFormatting`)
- Dictation AI post-processing + `AIProvider` / `LLMClient` / `ThinkingParsers`
- History, dictionary, backup, settings models
- Local API router/controllers/JSON models (not `NWListener` transport)
- Hotkey state-machine semantics from `GlobalHotkeyManager`
- Whisper download/cache concepts as `speech_runtime` backend config
- PCM ring-buffer ideas from `CoreAudioCaptureSupport.c` (platform-neutral buffer + WASAPI frontend)

## Target layout

```text
FluidVoice/                          # repo root; macOS Swift stays here
├── Sources/Fluid/ ...               # UNCHANGED reference
├── Fluid.xcodeproj/
├── Package.swift
├── LICENSE
├── README.md
├── flutter_app/
│   ├── lib/
│   │   ├── app/
│   │   ├── features/
│   │   ├── core/
│   │   └── main.dart
│   ├── windows/
│   └── pubspec.yaml
├── native_plugins/
│   ├── plugin_api/
│   ├── wasapi_audio/
│   ├── global_hotkeys/
│   ├── text_injection/
│   ├── overlay_window/
│   └── speech_runtime/
│       ├── whisper_cpp/
│       ├── onnx_runtime/
│       ├── vosk/
│       └── future_models/
├── shared/
│   ├── schemas/
│   └── documentation/
└── docs/
    ├── ARCHITECTURE.md
    ├── WINDOWS_PORT_PLAN.md
    ├── PLUGIN_API.md
    ├── BUILDING_WINDOWS.md
    └── CONTRIBUTING.md
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for IPC, WASAPI pipeline, and speech_runtime rules.

## Flutter UI requirements

- Settings
- Model selection
- Hotkey configuration
- Microphone selection
- Transcription display
- Overlay controls
- Application status
- History and onboarding feature modules

## Native replacement requirements

### Audio (WASAPI / FFI)

- Low-latency microphone capture
- Device enumeration and switching
- Thread-safe communication with Flutter
- Graceful device-change handling
- Pipeline: **Capture thread → lock-free ring buffer → audio worker → Dart Stream (FFI)**
- Never MethodChannel for audio; never call Dart from the WASAPI callback

### Hotkeys

- Global push-to-talk and configurable shortcuts
- Key down/up while another app is focused
- Native layer emits events; **HotkeyStateMachine in Dart**

### Text injection

- Primary: UI Automation
- Fallback: `SendInput`, clipboard inject with restore
- Target apps: browsers, Discord, chat, Office, editors

### Overlay

- Frameless, transparent, always on top
- Optional click-through, position control, smooth animations
- No Mac notch

### Speech (`speech_runtime`)

Backend priority:

1. Existing open-source models already supported where Windows-portable
2. whisper.cpp
3. Parakeet / ONNX where possible
4. Vosk

App API: unified `SpeechEngine` only.

## Phases

### Phase 0 — Docs + scaffold + interfaces (blocking)

- Design docs under `docs/` (this set)
- Scaffold `flutter_app/` with `app/`, `features/`, `core/` interfaces
- Scaffold `native_plugins/*` Dart/C++ **stubs only**
- **No** real WASAPI / hooks / UIA / whisper implementation yet

### Phase 1 — MVP dictation loop

Implementation priority:

1. Build system (Flutter Windows + native stub linkage)
2. Flutter UI shell
3. Microphone capture (WASAPI ring-buffer pipeline)
4. Global hotkey
5. Speech recognition (`speech_runtime` / whisper.cpp first)
6. Text injection (UIA → SendInput → clipboard)
7. Overlay
8. Settings persistence
9. Packaging (installer + portable)

Goal: hotkey → capture → transcribe → inject/overlay → basic settings/history.

### Phase 2 — Product parity (non-Apple)

- Rewrite / write mode
- Windows command mode (no AppleScript)
- Meeting / file transcription
- Local loopback HTTP API
- Model download
- Analytics opt-in, launch-at-login, media pause

### Phase 3 — More backends + polish

- ONNX / Parakeet-class and Vosk under `speech_runtime` without changing app call sites
- Per-app prompt routing
- Audio history export
- Installer / portable builds
- Feature parity checklist vs macOS README feature set

## Testing checklist

### Audio

- [ ] Microphone capture works
- [ ] Multiple devices
- [ ] Bluetooth headset support
- [ ] Device disconnect recovery

### Hotkeys

- [ ] Works globally
- [ ] Configurable
- [ ] No stuck keys

### Injection

- [ ] Chrome
- [ ] Edge
- [ ] Discord
- [ ] Notepad
- [ ] VS Code
- [ ] Office / other chat apps (stretch)

### Overlay

- [ ] Always on top
- [ ] Transparent
- [ ] Smooth

### Packaging

- [ ] Windows installer
- [ ] Portable build option

Also port the intent of `Tests/FluidDictationIntegrationTests` where applicable (audio convert, hotkey semantics, LLM request shaping, e2e dictation).

## Non-goals (initial)

- Breaking or rewriting the macOS Swift project
- Line-by-line Swift → Dart translation
- CoreML / Apple Speech on Windows
- Fluid Intelligence private runtime
- Notch UI
- Per-model top-level plugins exposed to the app
- Business logic in C++
- MethodChannel audio
- Electron / Qt

## Related docs

- [ARCHITECTURE.md](ARCHITECTURE.md)
- [PLUGIN_API.md](PLUGIN_API.md)
- [BUILDING_WINDOWS.md](BUILDING_WINDOWS.md)
- [CONTRIBUTING.md](CONTRIBUTING.md)
