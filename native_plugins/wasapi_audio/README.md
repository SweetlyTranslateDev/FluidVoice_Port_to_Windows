# wasapi_audio

Windows microphone capture via WASAPI.

## Pipeline (required)

```text
WASAPI Capture Thread → Lock-free Ring Buffer → Audio Worker → Dart Stream (FFI)
```

Do not call Dart from the WASAPI callback. Do not use MethodChannels for PCM.

## Phase 0

`cpp/wasapi_audio_stub.cpp` returns `FV_ERR_UNIMPLEMENTED`.

## Dart binding

See `dart/wasapi_audio_binding.dart` (FFI loader stub).
