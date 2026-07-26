# Contributing to the FluidVoice Windows Port

Thank you for helping with the parallel Flutter Windows port. This project preserves the original FluidVoice macOS application and adds Windows support alongside it under GPLv3.

## Parallel port rules

1. **Do not break macOS** — Do not delete, rewrite, or “clean up” the Swift tree (`Sources/Fluid`, `Fluid.xcodeproj`, `Package.swift`) unless a change is explicitly required and reviewed as safe for macOS.
2. **Add alongside** — New work belongs in `flutter_app/`, `native_plugins/`, `docs/`, and `shared/`.
3. **Not a line-by-line port** — Read the macOS reference, then implement equivalent behavior with correct Windows technologies.
4. **Explain before large changes** — In PRs or commits, list files you will create or modify and why.
5. **Document architecture changes** — Update `docs/` when IPC, layout, or plugin contracts change.

## Where code belongs

| Kind of code | Location |
|--------------|----------|
| UI screens / widgets | `flutter_app/lib/features/` |
| Dictation orchestration, settings, history, hotkey state machine | `flutter_app/lib/core/` |
| Platform interfaces | `flutter_app/lib/core/interfaces/` |
| WASAPI, speech backends, hooks, UIA | `native_plugins/` (C++ HOW only) |
| Shared JSON schemas | `shared/schemas/` |
| Design docs | `docs/` |

### Hard rules

- **No business logic in C++** — No dictation session state, AI routing, settings schemas, or hotkey mode logic in native code.
- **No per-model plugins at the app layer** — Use `SpeechEngine` / `speech_runtime`. Nest whisper/onnx/vosk under `native_plugins/speech_runtime/`.
- **No MethodChannel audio** — PCM uses Dart FFI and the WASAPI ring-buffer pipeline.
- **No Electron / Qt**.

## WASAPI reminder

```text
Capture thread → lock-free ring buffer → audio worker → Dart Stream (FFI)
```

Do not call into Dart from the WASAPI callback.

## Phase discipline

Before implementing Win32 APIs:

1. Dart interfaces exist in `flutter_app/lib/core/interfaces/`.
2. Plugin stubs exist under `native_plugins/`.
3. `docs/PLUGIN_API.md` and `docs/WINDOWS_PORT_PLAN.md` match the change.

Flutter knows **WHAT** it needs. Windows plugins know **HOW**.

## Coding standards

- Production-quality code; avoid temporary hacks in mainline.
- Comment Windows-specific APIs (WASAPI, UIA, hooks) with short intent notes.
- Keep modules separated; prefer small plugins over a single Win32 mega-DLL.
- Prefer native Windows APIs over unnecessary third-party frameworks.
- Match existing Dart style in `flutter_app/` once it exists.

## Testing expectations

Use the checklist in [WINDOWS_PORT_PLAN.md](WINDOWS_PORT_PLAN.md):

- Audio: devices, Bluetooth, disconnect recovery
- Hotkeys: global, configurable, no stuck keys
- Injection: Chrome, Edge, Discord, Notepad, VS Code
- Overlay: always on top, transparent, smooth
- Packaging: installer and portable (when that phase starts)

## License

Contributions are under the project’s **GPLv3** license. Preserve attribution and copyright headers where applicable. Do not add proprietary dependencies that conflict with GPLv3 without an explicit project decision.

## Getting started

1. Read [ARCHITECTURE.md](ARCHITECTURE.md) and [WINDOWS_PORT_PLAN.md](WINDOWS_PORT_PLAN.md).
2. Follow [BUILDING_WINDOWS.md](BUILDING_WINDOWS.md).
3. Start from interfaces and stubs; implement one plugin at a time in the priority order in the port plan.

## Related docs

- [ARCHITECTURE.md](ARCHITECTURE.md)
- [WINDOWS_PORT_PLAN.md](WINDOWS_PORT_PLAN.md)
- [PLUGIN_API.md](PLUGIN_API.md)
- [BUILDING_WINDOWS.md](BUILDING_WINDOWS.md)
