#include "../../plugin_api/include/fluidvoice_plugin_api.h"

#include "text_injector.h"

#include <cstdlib>
#include <mutex>
#include <string>

namespace {
TextInjector g_injector;
std::mutex g_mutex;
std::string g_lastError;

void setError(const char* msg) { g_lastError = msg ? msg : ""; }
}  // namespace

extern "C" {

FV_API fv_status fv_inject_text(const char* utf8_text) {
  if (!utf8_text) {
    setError("Text pointer is null");
    return FV_ERR_INVALID_ARG;
  }
  std::lock_guard<std::mutex> lock(g_mutex);
  if (g_injector.insertText(utf8_text) != 0) {
    setError(g_injector.lastError());
    return FV_ERR_INTERNAL;
  }
  g_lastError.clear();
  return FV_OK;
}

FV_API fv_status fv_inject_read_selection(char** out_text) {
  if (!out_text) {
    return FV_ERR_INVALID_ARG;
  }
  *out_text = nullptr;
  std::lock_guard<std::mutex> lock(g_mutex);
  if (g_injector.readSelection(out_text) != 0) {
    setError(g_injector.lastError());
    return FV_ERR_INTERNAL;
  }
  g_lastError.clear();
  return FV_OK;
}

FV_API void fv_inject_free(void* p) { std::free(p); }

FV_API const char* fv_inject_last_error(void) {
  if (!g_lastError.empty()) {
    return g_lastError.c_str();
  }
  return g_injector.lastError();
}

}  // extern "C"
