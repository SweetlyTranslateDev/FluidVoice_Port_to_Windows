#pragma once

/* Stable C ABI for Dart FFI. No C++ types across this boundary.
 * Business logic (dictation, settings, hotkey modes) must stay in Dart.
 */

#include <stdint.h>

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

typedef struct fv_audio_device {
  char* id;   /* WASAPI endpoint ID (UTF-8), caller frees via list free */
  char* name; /* Friendly name (UTF-8) */
  int32_t is_default;
} fv_audio_device;

typedef struct fv_audio_device_list {
  fv_audio_device* devices;
  int32_t count;
} fv_audio_device_list;

/** Initialize COM / audio subsystem. Call once before other fv_audio_* APIs. */
FV_API fv_status fv_audio_init(void);

/** Stop capture and release audio resources. Safe to call multiple times. */
FV_API void fv_audio_shutdown(void);

/** Enumerate active capture devices. Free with fv_audio_free_device_list. */
FV_API fv_audio_device_list* fv_audio_enumerate_devices(void);

FV_API void fv_audio_free_device_list(fv_audio_device_list* list);

/**
 * Select capture device by WASAPI id.
 * Pass NULL or empty string to use the default capture endpoint.
 */
FV_API fv_status fv_audio_set_device(const char* device_id);

/**
 * Start capture pipeline:
 * WASAPI capture thread -> lock-free ring -> worker (mono 16 kHz) -> output ring.
 * Dart must poll with fv_audio_read_floats (never MethodChannel).
 */
FV_API fv_status fv_audio_start(void);

FV_API fv_status fv_audio_stop(void);

/**
 * Non-blocking read of mono float32 samples at 16 kHz from the worker ring.
 * Writes up to max_samples into out_samples; sets *out_count.
 */
FV_API fv_status fv_audio_read_floats(
    float* out_samples,
    int32_t max_samples,
    int32_t* out_count);

/** Last audio error message (UTF-8). Valid until next fv_audio_* call. */
FV_API const char* fv_audio_last_error(void);

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
