# FluidVoice Plugin API

Contracts between `flutter_app/lib/core` (WHAT) and `native_plugins` (HOW).

## Transport matrix

| Capability | Transport | Rationale |
|------------|-----------|-----------|
| WASAPI PCM streaming | **Dart FFI** | High rate; MethodChannels are unsuitable |
| speech_runtime / whisper.cpp | **Dart FFI** | Large buffers + inference latency control |
| Global hotkey events | FFI or lightweight channel for event pump; prefer native callback → Dart isolate/port via FFI where possible | Down/up must be reliable |
| Text injection | FFI or MethodChannel (low frequency) | One-shot operations |
| Tray / window management | **MethodChannel** | Desktop host lifecycle |
| Settings bridge (OS integration) | **MethodChannel** | Low frequency |

**Forbidden:** streaming microphone audio over MethodChannels.

## Dart interfaces (`flutter_app/lib/core/interfaces`)

### AudioCapture

```dart
abstract class AudioCapture {
  Stream<AudioChunk> get audioStream;
  Future<List<AudioDeviceInfo>> listDevices();
  Future<void> setDevice(String deviceId);
  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
}
```

`AudioChunk` is 16-bit or float PCM metadata plus samples; the worker thread should deliver **mono 16 kHz** when possible so `SpeechEngine` receives a stable format.

### SpeechEngine (unified facade)

```dart
abstract class SpeechEngine {
  Future<void> prepare({required String modelId});
  Future<void> start();
  Future<void> stop();
  Future<void> streamAudio(AudioChunk chunk);
  Stream<TranscriptEvent> get transcripts;
  Future<TranscriptResult> transcribe(AudioBuffer audio);
  Future<void> dispose();
}
```

Call sites must use `SpeechEngine` only. Do **not** import whisper/onnx/vosk plugins from UI or feature code.

Backends under `native_plugins/speech_runtime/`:

| Backend | Directory | Phase |
|---------|-----------|-------|
| whisper.cpp | `whisper_cpp/` | Phase 1 |
| ONNX / Parakeet-class | `onnx_runtime/` | Phase 3 |
| Vosk | `vosk/` | Phase 3 |
| Future | `future_models/` | later |

### AIProvider

```dart
abstract class AIProvider {
  Future<String> enhance({
    required String transcript,
    required String? systemPrompt,
  });
}
```

Implemented in Dart with HTTP (OpenAI-compatible). No C++ required for MVP cloud/local HTTP enhancement.

### HotkeySource

```dart
abstract class HotkeySource {
  Stream<HotkeyEvent> get events;
  Future<void> setShortcut(HotkeyShortcut shortcut);
  Future<void> start();
  Future<void> stop();
}
```

`HotkeyStateMachine` in Dart consumes `HotkeyEvent` (key down/up, modifiers) and decides PTT/toggle behavior.

### TextInjector

```dart
abstract class TextInjector {
  Future<void> insertText(String text);
  Future<String?> readSelectedText();
}
```

Native strategy order: UI Automation → `SendInput` → clipboard paste with restore.

### TrayHost / OverlayHost

```dart
abstract class TrayHost {
  Future<void> setStatus(AppTrayStatus status);
  Future<void> setMenu(List<TrayMenuItem> items);
  Stream<TrayAction> get actions;
}

abstract class OverlayHost {
  Future<void> show();
  Future<void> hide();
  Future<void> setTranscript(String text);
  Future<void> setClickThrough(bool enabled);
  Future<void> setPosition({required double x, required double y});
}
```

These use MethodChannels (and Flutter multi-window APIs where appropriate).

### CredentialsStore

```dart
abstract class CredentialsStore {
  Future<void> writeSecret(String key, String value);
  Future<String?> readSecret(String key);
  Future<void> deleteSecret(String key);
}
```

Windows: Credential Manager / DPAPI behind the interface.

## FFI boundary (`native_plugins/plugin_api`)

Document stable C ABI headers here as they are added. Initial expectations:

| Symbol area | Ownership |
|-------------|-----------|
| `fv_audio_*` | `wasapi_audio` |
| `fv_speech_*` | `speech_runtime` facade |
| `fv_hotkey_*` | `global_hotkeys` |
| `fv_inject_*` | `text_injection` |

Rules:

- C ABI only at the FFI edge (no C++ types across Dart FFI).
- No dictation/session business state in native libraries.
- Errors returned as status codes + optional message buffer; Dart maps to exceptions.

## MethodChannel names (planned)

| Channel | Purpose |
|---------|---------|
| `fluidvoice/desktop_host` | Tray, main window show/hide, activation |
| `fluidvoice/overlay` | Overlay window control |
| `fluidvoice/settings_bridge` | OS startup registration and similar |

Exact method lists will expand as stubs gain implementations; keep this file updated.

## WASAPI plugin contract

```text
WASAPI Capture Thread → Lock-free Ring Buffer → Audio Worker → Dart Stream (FFI)
```

Worker responsibilities:

- Convert to target format (prefer mono float or PCM16 @ 16 kHz)
- Handle device removal / default-device changes without crashing the capture thread
- Never block the capture thread on Dart or locks held by Dart

## speech_runtime facade contract

Native facade selects backend by `modelId` / engine kind. Dart still sees one `SpeechEngine`.

```text
SpeechEngine (Dart)
    → fv_speech_* (FFI)
        → whisper_cpp | onnx_runtime | vosk | ...
```

## Plugin package layout

Each plugin under `native_plugins/<name>/`:

```text
<name>/
  dart/          # Dart binding implementing core interfaces
  cpp/           # Native implementation (stubs in Phase 0)
  README.md      # Plugin-specific notes
```

`plugin_api/` holds shared headers and documentation for the C ABI.

## Phase 0 expectation

- Interfaces exist in Dart and compile.
- Native folders contain stub libraries / headers that link but return `not implemented`.
- No real WASAPI, hooks, UIA, or whisper calls until Phase 1.
