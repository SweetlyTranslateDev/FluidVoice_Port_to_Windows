# speech_runtime

Unified speech recognition facade. App code calls `SpeechEngine` / `fv_speech_*` — never a per-model plugin API.

## Phase 1 backend

`whisper_cpp/` via [whisper.cpp](https://github.com/ggerganov/whisper.cpp) (CMake FetchContent, tag `v1.7.5`).

Pipeline:

1. Dart downloads/caches `ggml-tiny.en.bin` under `%AppData%\...\FluidVoice\models`
2. `fv_speech_prepare(path)` loads the model
3. `fv_speech_transcribe(float* mono16k, …)` runs `whisper_full` and returns UTF-8 text

## Build

Built as `fluidvoice_speech.dll` with the Flutter Windows runner (first configure fetches whisper.cpp).

```powershell
cd C:\dev\FluidVoice_Port_to_Windows\flutter_app
flutter build windows --debug
```
