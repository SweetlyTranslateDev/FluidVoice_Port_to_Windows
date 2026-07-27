#include "window_chrome_plugin.h"

#include <dwmapi.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>

namespace {

#ifndef DWMWA_SYSTEMBACKDROP_TYPE
#define DWMWA_SYSTEMBACKDROP_TYPE 38
#endif
#ifndef DWMSBT_NONE
#define DWMSBT_NONE 1
#endif
#ifndef DWMSBT_TRANSIENTWINDOW
#define DWMSBT_TRANSIENTWINDOW 3
#endif

HWND g_app_window = nullptr;

bool ReadEnabled(const flutter::EncodableValue* arguments) {
  if (const auto* args = std::get_if<flutter::EncodableMap>(arguments)) {
    auto it = args->find(flutter::EncodableValue("enabled"));
    if (it != args->end()) {
      if (const auto* b = std::get_if<bool>(&it->second)) {
        return *b;
      }
    }
  }
  return false;
}

void ApplyAlwaysOnTop(bool enabled) {
  if (!g_app_window) {
    return;
  }
  SetWindowPos(g_app_window, enabled ? HWND_TOPMOST : HWND_NOTOPMOST, 0, 0, 0,
               0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
}

void ApplyAcrylic(bool enabled) {
  if (!g_app_window) {
    return;
  }

  if (enabled) {
    const int backdrop = DWMSBT_TRANSIENTWINDOW;
    DwmSetWindowAttribute(g_app_window, DWMWA_SYSTEMBACKDROP_TYPE, &backdrop,
                          sizeof(backdrop));
    const MARGINS margins = {-1};
    DwmExtendFrameIntoClientArea(g_app_window, &margins);
  } else {
    const int backdrop = DWMSBT_NONE;
    DwmSetWindowAttribute(g_app_window, DWMWA_SYSTEMBACKDROP_TYPE, &backdrop,
                          sizeof(backdrop));
    const MARGINS margins = {0, 0, 0, 0};
    DwmExtendFrameIntoClientArea(g_app_window, &margins);
  }
}

class WindowChromePlugin : public flutter::Plugin {
 public:
  void AttachChannel(
      std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
          channel) {
    channel_ = std::move(channel);
  }

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (call.method_name() == "setAlwaysOnTop") {
      ApplyAlwaysOnTop(ReadEnabled(call.arguments()));
      result->Success(flutter::EncodableValue(true));
      return;
    }
    if (call.method_name() == "setAcrylic") {
      ApplyAcrylic(ReadEnabled(call.arguments()));
      result->Success(flutter::EncodableValue(true));
      return;
    }
    result->NotImplemented();
  }

 private:
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

}  // namespace

void WindowChromePluginSetAppWindow(HWND hwnd) { g_app_window = hwnd; }

void RegisterWindowChromePlugin(flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<WindowChromePlugin>();
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "fluidvoice/window_chrome",
          &flutter::StandardMethodCodec::GetInstance());

  auto* raw = plugin.get();
  channel->SetMethodCallHandler(
      [raw](const auto& call, auto result) {
        raw->HandleMethodCall(call, std::move(result));
      });
  raw->AttachChannel(std::move(channel));
  registrar->AddPlugin(std::move(plugin));
}
