# Building FluidVoice for Windows

Instructions for the **Flutter Windows port**. The macOS app still requires macOS + Xcode; see the root `README.md` and `build.sh` for that path.

## Prerequisites

| Tool | Notes |
|------|--------|
| Windows 10 or 11 | Target platform |
| Flutter SDK (stable) | Desktop Windows support enabled |
| Visual Studio 2022 | “Desktop development with C++” workload |
| CMake | Bundled with VS or standalone |
| Git | For dependencies / submodules later |

Enable Flutter Windows desktop:

```powershell
flutter config --enable-windows-desktop
flutter doctor
```

Confirm the Windows toolchain shows no blocking issues.

## Repository layout (Windows-relevant)

```text
flutter_app/          # Flutter application
native_plugins/       # C++ plugins + Dart bindings
docs/                 # Architecture and port docs
shared/schemas/       # Shared JSON schemas (as added)
```

The existing `Sources/Fluid`, `Fluid.xcodeproj`, and `Package.swift` tree is the macOS reference. Do not remove it. It does not build on Windows.

## Get dependencies

From the repo root:

```powershell
cd flutter_app
flutter pub get
```

## Run (debug)

```powershell
cd flutter_app
flutter run -d windows
```

## Build (release)

```powershell
cd flutter_app
flutter build windows --release
```

Output typically lands under:

```text
flutter_app\build\windows\x64\runner\Release\
```

## Native plugins

Phase 0 ships **stubs** under `native_plugins/*/cpp` that link and return “not implemented”.

When Phase 1 implementations land:

1. Build each plugin’s CMake project (or the umbrella CMake, if added).
2. Ensure the Flutter Windows runner links the produced DLLs / static libs as documented in each plugin `README.md`.
3. FFI libraries must be discoverable next to the executable or via explicit path loading in Dart.

Example stub build pattern (per plugin, when CMakeLists exist):

```powershell
cd native_plugins\wasapi_audio\cpp
cmake -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release
```

Exact generator/version may vary with the installed Visual Studio.

## speech_runtime / whisper.cpp

Whisper GGUF models are **not** bundled in Phase 0. When the whisper.cpp backend is wired:

- Document model download location under `%LOCALAPPDATA%\FluidVoice\models` (or similar).
- Prefer redistributable builds of whisper.cpp with CPU and optional GPU backends documented separately.
- App still selects models through `SpeechEngine.prepare(modelId: ...)`.

## Packaging (later phase)

Planned deliverables:

- Windows installer (e.g. MSIX or Inno Setup / WiX — choose when packaging work starts)
- Portable zip of the Release runner + native DLLs

Do not ship Electron or Qt wrappers.

## macOS reference build (not on Windows)

On a Mac with Xcode:

```bash
open Fluid.xcodeproj
# or
./build.sh
```

That path is independent of `flutter_app/`.

## Troubleshooting

| Issue | Check |
|-------|--------|
| `flutter` not found | Install Flutter; add to `PATH` |
| Windows desktop disabled | `flutter config --enable-windows-desktop` |
| VS C++ tools missing | Install VS 2022 Desktop C++ workload |
| Plugin DLL load fail | Ensure Release/Debug DLL matches runner arch (x64) and is beside the exe |
| Audio stub errors | Expected in Phase 0 until WASAPI is implemented |

## Related docs

- [ARCHITECTURE.md](ARCHITECTURE.md)
- [PLUGIN_API.md](PLUGIN_API.md)
- [WINDOWS_PORT_PLAN.md](WINDOWS_PORT_PLAN.md)
- [CONTRIBUTING.md](CONTRIBUTING.md)
