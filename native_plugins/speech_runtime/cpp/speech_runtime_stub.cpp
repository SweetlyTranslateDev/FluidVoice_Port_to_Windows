#define FLUIDVOICE_PLUGIN_EXPORTS
#include "../../plugin_api/include/fluidvoice_plugin_api.h"

/* Phase 0 stub. App must call speechEngine / fv_speech_* — never per-model APIs. */

extern "C" {

FV_API fv_status fv_speech_prepare(const char* /*model_id*/) {
  return FV_ERR_UNIMPLEMENTED;
}

FV_API fv_status fv_speech_transcribe(
    const float* /*samples*/,
    int /*sample_count*/,
    int /*sample_rate*/,
    char* out_text,
    int out_text_cap) {
  if (out_text == nullptr || out_text_cap <= 0) {
    return FV_ERR_INVALID_ARG;
  }
  out_text[0] = '\0';
  return FV_ERR_UNIMPLEMENTED;
}

}  // extern "C"
