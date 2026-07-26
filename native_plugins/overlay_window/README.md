# overlay_window

Frameless, always-on-top, click-through transcript overlay (Win32 layered popup).

Controlled via MethodChannel `fluidvoice/overlay` (registered in the Flutter
Windows runner). No notch UI on Windows. Audio must never use this channel.

## Methods

| Method | Args |
|--------|------|
| `show` | — |
| `hide` | — |
| `setTranscript` | `{ text: String }` |
| `setClickThrough` | `{ enabled: bool }` |
| `setPosition` | `{ x: number, y: number }` |
