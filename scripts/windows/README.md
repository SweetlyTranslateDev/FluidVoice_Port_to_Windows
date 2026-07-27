# Windows packaging scripts

| Script | Purpose |
|--------|---------|
| `build_portable.ps1` | `flutter build windows --release`, copy runner + DLLs to `dist\FluidVoice-portable\`, zip |
| `build_installer.ps1` | Portable build, then Inno Setup (`FluidVoice.iss`) if `ISCC.exe` is installed |
| `FluidVoice.iss` | Inno Setup 6 definition (per-user install, x64) |
| `verify_speech_smoke.ps1` | Native Whisper + Parakeet prepare/transcribe smoke test |

## Usage

Prefer a path **without `;`** (junction: `C:\dev\FluidVoice_Port_to_Windows`):

```powershell
cd C:\dev\FluidVoice_Port_to_Windows
.\scripts\windows\build_portable.ps1
.\scripts\windows\build_installer.ps1
```

Outputs land under `dist\`:

- `FluidVoice-portable\` / `FluidVoice-portable.zip`
- `FluidVoice-Windows-Setup-1.0.0.exe` (requires [Inno Setup 6](https://jrsoftware.org/isinfo.php))

Models download on first run into AppData; they are not bundled in the installer.

## GitHub Release text

Paste **[docs/WINDOWS_RELEASE_NOTES.md](../../docs/WINDOWS_RELEASE_NOTES.md)** into the Release description so downloaders see **ported vs not ported**. The Setup wizard also shows `INSTALLER_INFO.txt` before/after install.
