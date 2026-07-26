# wasapi_audio

Windows microphone capture via WASAPI (FFI only).

## Pipeline

```text
WASAPI Capture Thread
        →
Lock-free Ring Buffer (48 kHz stereo PCM16)
        →
Audio Worker Thread (mono 16 kHz)
        →
Output ring → Dart poll via fv_audio_read_floats
```

Capture never calls into Dart. Audio never uses MethodChannels.

## Reference

Implementation adapted from Sweetly production patterns in
`sweetly-flutter/native/src` (`wasapi_capture`, `ring_buffer`, device enum,
48k→16k downmix). Sweetly sources are **not** modified.

## Build

Built as `fluidvoice_wasapi.dll` via Flutter Windows CMake
(`flutter_app/windows/CMakeLists.txt` adds this directory) or standalone:

```powershell
cd native_plugins\wasapi_audio\cpp
cmake -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release
```

## Dart

`flutter_app/lib/core/platform/wasapi_audio_capture.dart` implements `AudioCapture`.
