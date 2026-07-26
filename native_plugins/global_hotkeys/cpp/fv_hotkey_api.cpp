#include "../../plugin_api/include/fluidvoice_plugin_api.h"

#include "hotkey_hook.h"

#include <memory>
#include <mutex>
#include <string>

namespace {
std::unique_ptr<HotkeyHook> g_hook;
std::mutex g_mutex;
std::string g_lastError;

void setError(const char* msg) { g_lastError = msg ? msg : ""; }
}  // namespace

extern "C" {

FV_API fv_status fv_hotkey_init(void) {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (g_hook) {
    return FV_OK;
  }
  g_hook = std::make_unique<HotkeyHook>();
  if (g_hook->init() != 0) {
    setError(g_hook->lastError());
    g_hook.reset();
    return FV_ERR_INTERNAL;
  }
  g_lastError.clear();
  return FV_OK;
}

FV_API void fv_hotkey_shutdown(void) {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (g_hook) {
    g_hook->shutdown();
    g_hook.reset();
  }
}

FV_API fv_status fv_hotkey_set_shortcut(int32_t vk_code, int32_t modifiers) {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (!g_hook) {
    setError("Hotkeys not initialized");
    return FV_ERR_STATE;
  }
  if (g_hook->setShortcut(vk_code, modifiers) != 0) {
    setError(g_hook->lastError());
    return FV_ERR_INVALID_ARG;
  }
  return FV_OK;
}

FV_API fv_status fv_hotkey_start(void) {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (!g_hook) {
    setError("Hotkeys not initialized");
    return FV_ERR_STATE;
  }
  if (g_hook->start() != 0) {
    setError(g_hook->lastError());
    return FV_ERR_INTERNAL;
  }
  return FV_OK;
}

FV_API fv_status fv_hotkey_stop(void) {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (g_hook) {
    g_hook->stop();
  }
  return FV_OK;
}

FV_API fv_status fv_hotkey_poll(fv_hotkey_event* out_events, int32_t max_events,
                                int32_t* out_count) {
  if (!out_events || !out_count || max_events <= 0) {
    return FV_ERR_INVALID_ARG;
  }
  *out_count = 0;

  std::lock_guard<std::mutex> lock(g_mutex);
  if (!g_hook) {
    setError("Hotkeys not initialized");
    return FV_ERR_STATE;
  }
  *out_count = g_hook->poll(out_events, max_events);
  return FV_OK;
}

FV_API const char* fv_hotkey_last_error(void) {
  if (!g_lastError.empty()) {
    return g_lastError.c_str();
  }
  if (g_hook) {
    return g_hook->lastError();
  }
  return "";
}

}  // extern "C"
