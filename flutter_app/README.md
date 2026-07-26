# FluidVoice Flutter (Windows)

Parallel Windows app for FluidVoice. The macOS Swift tree at the repository root stays untouched.

## Status (MVP — ready to test)

Core loop is implemented:

**Hold F8 → WASAPI capture → whisper.cpp → text inject + overlay → history**

Also included: tray, settings persistence, model picker (`tiny.en` / `base.en`), launch-at-login, Credential Manager API keys, AI output modes, loopback Local API, packaging scripts.

## Run

Prefer a path **without `;`** (junction example: `C:\dev\FluidVoice_Port_to_Windows`):

```powershell
cd C:\dev\FluidVoice_Port_to_Windows\flutter_app
flutter pub get
flutter run -d windows
```

## Package

```powershell
cd C:\dev\FluidVoice_Port_to_Windows
.\scripts\windows\build_portable.ps1
.\scripts\windows\build_installer.ps1
```

## Docs

- [Architecture](../docs/ARCHITECTURE.md)
- [Windows port plan](../docs/WINDOWS_PORT_PLAN.md)
- [Plugin API](../docs/PLUGIN_API.md)
- [Building Windows](../docs/BUILDING_WINDOWS.md)
- [Local API](../docs/LOCAL_API.md)
- [Windows quick start](../WINDOWS.md)
- [Contributing](../docs/CONTRIBUTING.md)
