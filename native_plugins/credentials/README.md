# credentials

Windows Credential Manager (`CredWrite` / `CredRead` / `CredDelete`) for secrets.

MethodChannel: `fluidvoice/credentials`

Targets are stored as `FluidVoice/<key>` (e.g. `FluidVoice/ai_api_key`).

| Method | Args |
|--------|------|
| `write` | `{ key, value }` |
| `read` | `{ key }` → `String?` |
| `delete` | `{ key }` |
