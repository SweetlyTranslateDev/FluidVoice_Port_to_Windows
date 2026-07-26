#define FLUIDVOICE_PLUGIN_EXPORTS
#include "../../plugin_api/include/fluidvoice_plugin_api.h"

/* Phase 0 stub. Phase 1: WASAPI capture thread → ring buffer → worker → FFI. */

extern "C" {

FV_API fv_status fv_audio_init(void) { return FV_ERR_UNIMPLEMENTED; }

FV_API fv_status fv_audio_shutdown(void) { return FV_OK; }

FV_API fv_status fv_audio_start(void) { return FV_ERR_UNIMPLEMENTED; }

FV_API fv_status fv_audio_stop(void) { return FV_OK; }

}  // extern "C"
