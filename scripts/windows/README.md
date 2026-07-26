# Windows packaging scripts

| Script | Purpose |
|--------|---------|
| `build_portable.ps1` | `flutter build windows --release` + zip of Release tree |
| `build_installer.ps1` | Portable build, then Inno Setup (`FluidVoice.iss`) if ISCC is installed |
| `FluidVoice.iss` | Inno Setup 6 definition |

Use the junction path without `;` (for example `C:\dev\FluidVoice_Port_to_Windows`) when invoking Flutter.

```powershell
cd C:\dev\FluidVoice_Port_to_Windows
.\scripts\windows\build_portable.ps1
.\scripts\windows\build_installer.ps1
```

Output defaults to `flutter_app\dist\`.
