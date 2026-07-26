# native_plugins

Windows HOW layer for FluidVoice. Dart `lib/core` owns business logic.

| Plugin | Transport | Role |
|--------|-----------|------|
| `wasapi_audio` | FFI | Mic capture (ring-buffer pipeline) |
| `speech_runtime` | FFI | Unified STT facade + nested backends |
| `global_hotkeys` | FFI / events | Key down/up only |
| `text_injection` | FFI | UIA / SendInput |
| `overlay_window` | MethodChannel | Always-on-top overlay |
| `plugin_api` | C ABI headers | Shared FFI contracts |

See [docs/PLUGIN_API.md](../docs/PLUGIN_API.md).
