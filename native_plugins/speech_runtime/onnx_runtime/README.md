# onnx_runtime / Parakeet (Phase 3)

Parakeet TDT runs under the unified `speech_runtime` facade via **sherpa-onnx** (ONNX Runtime).

## How it is built

[`../cpp/CMakeLists.txt`](../cpp/CMakeLists.txt) downloads a pinned Windows prebuilt:

- `sherpa-onnx-v1.12.23-win-x64-shared-MD-Release-no-tts.tar.bz2`
- Links `sherpa-onnx-c-api.lib` into `fluidvoice_speech.dll`
- Copies `sherpa-onnx-c-api.dll`, `onnxruntime.dll`, and `onnxruntime_providers_shared.dll` beside the Flutter runner

First configure downloads ~15MB of runtime libs (not the ASR model).

## Model

Default Parakeet bundle (English, int8):

- id: `parakeet-tdt-0.6b-v2-int8`
- archive: `sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8.tar.bz2` from sherpa-onnx `asr-models` release assets
- extracted under `%AppData%\…\FluidVoice\models\parakeet-tdt-0.6b-v2-int8\`
- must contain `encoder*.onnx`, `decoder*.onnx`, `joiner*.onnx`, `tokens.txt`

Dart downloads/extracts this; native `fv_speech_prepare` receives the directory path.

## App call sites

Unchanged: Dart still uses `SpeechEngine.prepare` / `transcribe` → `fv_speech_*`.
