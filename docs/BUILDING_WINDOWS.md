# Building FluidVoice for Windows

Instructions for the **Flutter Windows port**. The macOS app still requires macOS + Xcode; see the root `README.md` and `build.sh` for that path.

## Prerequisites

| Tool | Notes |
|------|--------|
| Windows 10 or 11 | Target platform |
| Flutter SDK (stable) | Desktop Windows support enabled |
| Visual Studio 2022 | “Desktop development with C++” workload |
| CMake | Prefer `C:\Program Files\CMake\bin\cmake.exe` (not MSYS) |
| Git | For dependencies / submodules later |

**Path note:** Flutter rejects workspace paths containing `;`. If the repo lives under a path with a semicolon, use a directory junction without that character (for example `C:\dev\FluidVoice_Port_to_Windows`) for `flutter build` / `flutter run`.

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

## Build (release) — preferred for STT speed

```powershell
cd flutter_app
flutter build windows --release
```

Or run Release directly:

```powershell
flutter run -d windows --release
```

Output typically lands under:

```text
flutter_app\build\windows\x64\runner\Release\
```

Release also installs `sherpa-onnx-c-api.dll` and `onnxruntime*.dll` beside the exe.

## Native plugins

### wasapi_audio (Phase 1)

`fluidvoice_wasapi.dll` is built automatically with the Flutter Windows runner
(`flutter_app/windows/CMakeLists.txt` adds `native_plugins/wasapi_audio/cpp`).

```powershell
cd flutter_app
flutter build windows
```

The DLL is installed next to `fluidvoice_app.exe`. Dart loads it via
`DynamicLibrary.open('fluidvoice_wasapi.dll')`.

Standalone build:

```powershell
cd native_plugins\wasapi_audio\cpp
cmake -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release
```

Native FFI DLLs built with the runner:

- `fluidvoice_wasapi.dll`
- `fluidvoice_hotkeys.dll`
- `fluidvoice_speech.dll` (whisper.cpp + sherpa-onnx / Parakeet)
- `fluidvoice_inject.dll`

Overlay and tray are compiled into the runner (MethodChannels), not separate DLLs.

## speech_runtime (Whisper + Parakeet)

Models download on first use into the app support `FluidVoice\models` folder.

| Model id | Path kind |
|----------|-----------|
| `tiny.en` / `base.en` | ggml `.bin` file |
| `parakeet-tdt-0.6b-v2-int8` | ONNX directory (`encoder`/`decoder`/`joiner` + `tokens.txt`) |

- App selects models through `SpeechEngine.prepare(modelId: ...)`.
- First CMake configure clones whisper.cpp (`v1.7.5`) and downloads pinned sherpa-onnx Windows prebuilts (`v1.12.23` shared MD Release no-tts); first configure can be slow.
- See `native_plugins/speech_runtime/onnx_runtime/README.md`.

## Packaging

Scripts live under `scripts/windows/`:

```powershell
cd C:\dev\FluidVoice_Port_to_Windows
.\scripts\windows\build_portable.ps1
.\scripts\windows\build_installer.ps1
```

| Deliverable | How |
|-------------|-----|
| Portable folder + zip | `build_portable.ps1` → `dist\FluidVoice-portable\` and `.zip` |
| Installer | `build_installer.ps1` + [Inno Setup 6](https://jrsoftware.org/isinfo.php) (`ISCC.exe`) → `dist\FluidVoice-Windows-Setup-*.exe` |

The installer script still produces the portable zip if Inno Setup is missing. `dist/` is gitignored.

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
| Path contains `;` | Use a junction (e.g. `C:\dev\FluidVoice_Port_to_Windows`) for Flutter/CMake |
| Whisper FetchContent fail | Network access required on first configure; delete `build\windows\x64\_deps` to retry |
| Tray close quits unexpectedly | Close should hide to tray; use tray **Quit** to exit |

## Related docs

- [ARCHITECTURE.md](ARCHITECTURE.md)
- [PLUGIN_API.md](PLUGIN_API.md)
- [WINDOWS_PORT_PLAN.md](WINDOWS_PORT_PLAN.md)
- [CONTRIBUTING.md](CONTRIBUTING.md)
