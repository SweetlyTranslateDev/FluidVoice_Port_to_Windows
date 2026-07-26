# tray_host

Win32 `Shell_NotifyIcon` system tray, controlled via MethodChannel `fluidvoice/tray`.

Registered in the Flutter Windows runner (same pattern as `overlay_window`).

## Methods

| Method | Args |
|--------|------|
| `start` | — |
| `stop` | — |
| `setTooltip` | `{ text }` |
| `setStatus` | `{ status: idle\|listening\|processing\|error }` |
| `setMenu` | `[{ id, label, enabled }]` |
| `showApp` / `hideApp` / `quitApp` | — |

Native → Dart: `action` with menu/click id string.
