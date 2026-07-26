# global_hotkeys

Global keyboard capture via `WH_KEYBOARD_LL` on a dedicated message-pump thread.

## Design

- Native layer only emits key down/up for the configured shortcut
- Dart `HotkeyStateMachine` owns push-to-talk / toggle semantics
- Dart polls `fv_hotkey_poll` (FFI) — no MethodChannel for input events

## Build

Built as `fluidvoice_hotkeys.dll` with the Flutter Windows runner, or:

```powershell
cmake -B build -S . -G "Visual Studio 17 2022" -A x64
cmake --build build --config Debug
```
