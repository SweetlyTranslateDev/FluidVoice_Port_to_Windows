#pragma once

/* Stable C ABI for Dart FFI. No C++ types across this boundary.
 * Business logic (dictation, settings, hotkey modes) must stay in Dart.
 */

#ifdef __cplusplus
extern "C" {
#endif

#ifdef _WIN32
#ifdef FLUIDVOICE_PLUGIN_EXPORTS
#define FV_API __declspec(dllexport)
#else
#define FV_API __declspec(dllimport)
#endif
#else
#define FV_API
#endif

typedef enum fv_status {
  FV_OK = 0,
  FV_ERR_UNIMPLEMENTED = 1,
  FV_ERR_INVALID_ARG = 2,
  FV_ERR_STATE = 3,
  FV_ERR_INTERNAL = 4
} fv_status;

/* --- wasapi_audio --- */
FV_API fv_status fv_audio_init(void);
FV_API fv_status fv_audio_shutdown(void);
FV_API fv_status fv_audio_start(void);
FV_API fv_status fv_audio_stop(void);

/* --- speech_runtime facade (not per-model) --- */
FV_API fv_status fv_speech_prepare(const char* model_id);
FV_API fv_status fv_speech_transcribe(
    const float* samples,
    int sample_count,
    int sample_rate,
    char* out_text,
    int out_text_cap);

/* --- global_hotkeys --- */
FV_API fv_status fv_hotkey_start(void);
FV_API fv_status fv_hotkey_stop(void);

/* --- text_injection --- */
FV_API fv_status fv_inject_text(const char* utf8_text);

#ifdef __cplusplus
}
#endif
