#pragma once

#include <flutter/plugin_registrar_windows.h>
#include <windows.h>

/** Registers MethodChannel fluidvoice/tray on the Flutter Windows engine. */
void RegisterTrayPlugin(flutter::PluginRegistrarWindows* registrar);

/** Provide the main Flutter HWND so tray can show/hide/quit the app. */
void TrayPluginSetAppWindow(HWND hwnd);
