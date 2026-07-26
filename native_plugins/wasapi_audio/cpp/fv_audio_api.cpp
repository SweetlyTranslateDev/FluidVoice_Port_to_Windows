/**
 * C ABI for Dart FFI — thin wrapper over AudioEngine.
 */

#include "../../plugin_api/include/fluidvoice_plugin_api.h"

#include "audio_engine.h"

#include <cstring>
#include <memory>
#include <mutex>
#include <string>

namespace {
std::unique_ptr<AudioEngine> g_engine;
std::mutex g_mutex;
std::string g_lastError;

void setError(const char* msg) {
  g_lastError = msg ? msg : "";
}
}  // namespace

extern "C" {

FV_API fv_status fv_audio_init(void) {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (g_engine) {
    return FV_OK;
  }
  g_engine = std::make_unique<AudioEngine>();
  const int result = g_engine->init();
  if (result != 0) {
    setError(g_engine->lastError());
    g_engine.reset();
    return FV_ERR_INTERNAL;
  }
  g_lastError.clear();
  return FV_OK;
}

FV_API void fv_audio_shutdown(void) {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (g_engine) {
    g_engine->shutdown();
    g_engine.reset();
  }
}

FV_API fv_audio_device_list* fv_audio_enumerate_devices(void) {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (!g_engine) {
    setError("Audio not initialized");
    return nullptr;
  }

  const auto devices = g_engine->enumerateCaptureDevices();
  auto* list = new fv_audio_device_list();
  list->count = static_cast<int32_t>(devices.size());
  list->devices =
      list->count > 0 ? new fv_audio_device[static_cast<size_t>(list->count)]
                      : nullptr;

  for (size_t i = 0; i < devices.size(); ++i) {
    char* id = new char[devices[i].id.size() + 1];
    strcpy_s(id, devices[i].id.size() + 1, devices[i].id.c_str());
    list->devices[i].id = id;

    char* name = new char[devices[i].name.size() + 1];
    strcpy_s(name, devices[i].name.size() + 1, devices[i].name.c_str());
    list->devices[i].name = name;

    list->devices[i].is_default = devices[i].isDefault ? 1 : 0;
  }

  return list;
}

FV_API void fv_audio_free_device_list(fv_audio_device_list* list) {
  if (!list) {
    return;
  }
  for (int32_t i = 0; i < list->count; ++i) {
    delete[] list->devices[i].id;
    delete[] list->devices[i].name;
  }
  delete[] list->devices;
  delete list;
}

FV_API fv_status fv_audio_set_device(const char* device_id) {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (!g_engine) {
    setError("Audio not initialized");
    return FV_ERR_STATE;
  }
  const std::string id = device_id ? device_id : "";
  if (g_engine->setDevice(id) != 0) {
    setError(g_engine->lastError());
    return FV_ERR_STATE;
  }
  return FV_OK;
}

FV_API fv_status fv_audio_start(void) {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (!g_engine) {
    setError("Audio not initialized");
    return FV_ERR_STATE;
  }
  if (g_engine->start() != 0) {
    setError(g_engine->lastError());
    return FV_ERR_INTERNAL;
  }
  return FV_OK;
}

FV_API fv_status fv_audio_stop(void) {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (!g_engine) {
    return FV_OK;
  }
  g_engine->stop();
  return FV_OK;
}

FV_API fv_status fv_audio_read_floats(float* out_samples, int32_t max_samples,
                                      int32_t* out_count) {
  if (!out_samples || !out_count || max_samples <= 0) {
    return FV_ERR_INVALID_ARG;
  }
  *out_count = 0;

  std::lock_guard<std::mutex> lock(g_mutex);
  if (!g_engine) {
    setError("Audio not initialized");
    return FV_ERR_STATE;
  }

  const int got = g_engine->readFloats(out_samples, max_samples);
  *out_count = got;
  return FV_OK;
}

FV_API const char* fv_audio_last_error(void) {
  if (!g_lastError.empty()) {
    return g_lastError.c_str();
  }
  if (g_engine) {
    return g_engine->lastError();
  }
  return "";
}

}  // extern "C"
