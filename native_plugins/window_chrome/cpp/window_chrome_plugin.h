#pragma once

#include <flutter/plugin_registrar_windows.h>
#include <windows.h>

void RegisterWindowChromePlugin(flutter::PluginRegistrarWindows* registrar);

// Called from runner so the plugin can target the Flutter host HWND.
void WindowChromePluginSetAppWindow(HWND hwnd);
