#include "../../plugin_api/include/fluidvoice_plugin_api.h"

#include "speech_engine.h"

#include <cstdlib>
#include <memory>
#include <mutex>
#include <string>

namespace {
std::unique_ptr<SpeechEngine> g_engine;
std::mutex g_mutex;
std::string g_lastError;

void setError(const char* msg) { g_lastError = msg ? msg : ""; }
}  // namespace

extern "C" {

FV_API fv_status fv_speech_init(void) {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (g_engine) {
    return FV_OK;
  }
  g_engine = std::make_unique<SpeechEngine>();
  if (g_engine->init() != 0) {
    setError(g_engine->lastError());
    g_engine.reset();
    return FV_ERR_INTERNAL;
  }
  g_lastError.clear();
  return FV_OK;
}

FV_API void fv_speech_shutdown(void) {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (g_engine) {
    g_engine->shutdown();
    g_engine.reset();
  }
}

FV_API fv_status fv_speech_prepare(const char* model_path) {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (!g_engine) {
    setError("Speech runtime not initialized");
    return FV_ERR_STATE;
  }
  if (!model_path || model_path[0] == '\0') {
    setError("Model path is empty");
    return FV_ERR_INVALID_ARG;
  }
  if (g_engine->prepare(model_path) != 0) {
    setError(g_engine->lastError());
    return FV_ERR_INTERNAL;
  }
  return FV_OK;
}

FV_API fv_status fv_speech_transcribe(const float* samples, int sample_count,
                                      int sample_rate, char** out_text) {
  if (!out_text) {
    return FV_ERR_INVALID_ARG;
  }
  *out_text = nullptr;

  std::lock_guard<std::mutex> lock(g_mutex);
  if (!g_engine) {
    setError("Speech runtime not initialized");
    return FV_ERR_STATE;
  }
  if (g_engine->transcribe(samples, sample_count, sample_rate, out_text) != 0) {
    setError(g_engine->lastError());
    return FV_ERR_INTERNAL;
  }
  return FV_OK;
}

FV_API void fv_speech_free(void* p) {
  std::free(p);
}

FV_API const char* fv_speech_last_error(void) {
  if (!g_lastError.empty()) {
    return g_lastError.c_str();
  }
  if (g_engine) {
    return g_engine->lastError();
  }
  return "";
}

}  // extern "C"
