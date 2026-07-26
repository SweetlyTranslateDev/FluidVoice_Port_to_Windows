# FluidVoice Flutter (Windows)

Parallel Windows UI shell for FluidVoice. The macOS Swift application at the repository root remains the reference implementation and must not be broken.

## Phase 0 status

- Dart core interfaces and managers under `lib/core/`
- Feature UI shells under `lib/features/`
- Native plugins are stubs under `../native_plugins/` (no WASAPI/hooks/whisper yet)

## Docs

- [Architecture](../docs/ARCHITECTURE.md)
- [Windows port plan](../docs/WINDOWS_PORT_PLAN.md)
- [Plugin API](../docs/PLUGIN_API.md)
- [Building Windows](../docs/BUILDING_WINDOWS.md)
- [Contributing](../docs/CONTRIBUTING.md)

## Run

```powershell
flutter pub get
flutter run -d windows
```
