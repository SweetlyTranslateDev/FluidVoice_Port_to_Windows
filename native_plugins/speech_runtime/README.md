# speech_runtime

Unified speech recognition facade for FluidVoice Windows.

## App contract

```dart
speechEngine.transcribe(audio);
```

Not `whisperPlugin.transcribe(audio)`.

## Backends (nested)

| Backend | Path | Phase |
|---------|------|-------|
| whisper.cpp | `whisper_cpp/` | 1 |
| ONNX / Parakeet-class | `onnx_runtime/` | 3 |
| Vosk | `vosk/` | 3 |
| Future | `future_models/` | later |

Phase 0 ships `cpp/speech_runtime_stub.cpp` only.
