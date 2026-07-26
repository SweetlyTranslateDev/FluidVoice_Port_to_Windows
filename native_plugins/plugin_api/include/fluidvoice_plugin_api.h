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

FV_API fv_status fv_speech_init(void);
FV_API void fv_speech_shutdown(void);

/**
 * Load a local Whisper model file (ggml/gguf path).
 * model_id historically meant a logical id; Windows passes a filesystem path.
 */
FV_API fv_status fv_speech_prepare(const char* model_path);

/**
 * Batch-transcribe mono PCM float samples.
 * On success, *out_text is a malloc'd UTF-8 string; free with fv_speech_free.
 */
FV_API fv_status fv_speech_transcribe(
    const float* samples,
    int sample_count,
    int sample_rate,
    char** out_text);

FV_API void fv_speech_free(void* p);

FV_API const char* fv_speech_last_error(void);

/* --- global_hotkeys --- */

#define FV_HOTKEY_MOD_CONTROL 0x0001
#define FV_HOTKEY_MOD_ALT     0x0002
#define FV_HOTKEY_MOD_SHIFT   0x0004
#define FV_HOTKEY_MOD_WIN     0x0008

#define FV_HOTKEY_EVENT_DOWN 1
#define FV_HOTKEY_EVENT_UP   2

typedef struct fv_hotkey_event {
  int32_t type;       /* FV_HOTKEY_EVENT_DOWN / UP */
  int32_t vk_code;    /* Win32 virtual-key code */
  int32_t modifiers;  /* FV_HOTKEY_MOD_* bitfield at event time */
} fv_hotkey_event;

FV_API fv_status fv_hotkey_init(void);
FV_API void fv_hotkey_shutdown(void);

/** Configure the shortcut to emit (vk + required modifiers). */
FV_API fv_status fv_hotkey_set_shortcut(int32_t vk_code, int32_t modifiers);

/**
 * Install WH_KEYBOARD_LL on a dedicated message-pump thread.
 * Emits matching key down/up into a queue; Dart polls with fv_hotkey_poll.
 * No dictation / PTT business logic here.
 */
FV_API fv_status fv_hotkey_start(void);
FV_API fv_status fv_hotkey_stop(void);

/** Non-blocking drain of queued events into out[0..max_events). */
FV_API fv_status fv_hotkey_poll(
    fv_hotkey_event* out_events,
    int32_t max_events,
    int32_t* out_count);

FV_API const char* fv_hotkey_last_error(void);

/* --- text_injection --- */

FV_API fv_status fv_inject_text(const char* utf8_text);

/**
 * Read currently selected text in the focused control.
 * On success, *out_text is malloc'd UTF-8 (may be empty); free with fv_inject_free.
 */
FV_API fv_status fv_inject_read_selection(char** out_text);

FV_API void fv_inject_free(void* p);

FV_API const char* fv_inject_last_error(void);

/** Toggle system media play/pause (VK_MEDIA_PLAY_PAUSE). */
FV_API fv_status fv_media_play_pause(void);

#ifdef __cplusplus
}
#endif

