# whisper_cpp backend

Nested under `speech_runtime`. Not a top-level app plugin.

Phase 1: whisper.cpp `v1.7.5` is pulled via CMake FetchContent from
`native_plugins/speech_runtime/cpp/CMakeLists.txt` and linked into
`fluidvoice_speech.dll`. App code uses only the `fv_speech_*` / `SpeechEngine` facade.
