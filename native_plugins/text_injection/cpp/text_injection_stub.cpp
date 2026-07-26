#define FLUIDVOICE_PLUGIN_EXPORTS
#include "../../plugin_api/include/fluidvoice_plugin_api.h"

/* Phase 0 stub. Phase 1: UI Automation → SendInput → clipboard restore. */

extern "C" {

FV_API fv_status fv_inject_text(const char* /*utf8_text*/) {
  return FV_ERR_UNIMPLEMENTED;
}

}  // extern "C"
