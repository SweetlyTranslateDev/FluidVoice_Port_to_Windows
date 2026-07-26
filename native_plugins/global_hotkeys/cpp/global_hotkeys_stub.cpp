#define FLUIDVOICE_PLUGIN_EXPORTS
#include "../../plugin_api/include/fluidvoice_plugin_api.h"

/* Phase 0 stub. Phase 1: RegisterHotKey and/or low-level hooks.
 * HotkeyStateMachine stays in Dart.
 */

extern "C" {

FV_API fv_status fv_hotkey_start(void) { return FV_ERR_UNIMPLEMENTED; }

FV_API fv_status fv_hotkey_stop(void) { return FV_OK; }

}  // extern "C"
