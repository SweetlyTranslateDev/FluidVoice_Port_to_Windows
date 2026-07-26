# Local API (Windows)

Loopback-only HTTP API inspired by the macOS `LocalAPIServer`.

- Bind address: `127.0.0.1` only
- Default port: `47733`
- Enable in **Settings → Local API**, then restart the app

## Endpoints

| Method | Path | Body | Notes |
|--------|------|------|-------|
| `GET` | `/v1/health` | — | `{ status, version }` |
| `GET` | `/v1/history` | — | Saved transcripts |
| `POST` | `/v1/postprocess` | `{ text, mode? }` | `mode`: `enhance` \| `rewrite` \| `write` |
| `POST` | `/v1/transcribe` | `{ samples: number[], sampleRate? }` | Float PCM; default 16 kHz |

`POST /v1/postprocess` requires an AI API key in Windows Credential Manager.
