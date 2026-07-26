#include "overlay_plugin.h"

#include "overlay_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <windows.h>

#include <memory>
#include <string>

namespace {

std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) {
    return L"";
  }
  const int n = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(),
                                    static_cast<int>(utf8.size()), nullptr, 0);
  if (n <= 0) {
    return L"";
  }
  std::wstring out(static_cast<size_t>(n), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), static_cast<int>(utf8.size()),
                      out.data(), n);
  return out;
}

class OverlayPlugin : public flutter::Plugin {
public:
  OverlayPlugin() { overlay_.create(); }
  ~OverlayPlugin() override { overlay_.destroy(); }

  void AttachChannel(
      std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel) {
    channel_ = std::move(channel);
  }

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    const auto& method = call.method_name();
    if (method == "show") {
      overlay_.show();
      result->Success();
      return;
    }
    if (method == "hide") {
      overlay_.hide();
      result->Success();
      return;
    }
    if (method == "setTranscript") {
      std::string text;
      if (const auto* args =
              std::get_if<flutter::EncodableMap>(call.arguments())) {
        auto it = args->find(flutter::EncodableValue("text"));
        if (it != args->end()) {
          if (const auto* s = std::get_if<std::string>(&it->second)) {
            text = *s;
          }
        }
      }
      overlay_.setTranscript(Utf8ToWide(text));
      result->Success();
      return;
    }
    if (method == "setClickThrough") {
      bool enabled = true;
      if (const auto* args =
              std::get_if<flutter::EncodableMap>(call.arguments())) {
        auto it = args->find(flutter::EncodableValue("enabled"));
        if (it != args->end()) {
          if (const auto* b = std::get_if<bool>(&it->second)) {
            enabled = *b;
          }
        }
      }
      overlay_.setClickThrough(enabled);
      result->Success();
      return;
    }
    if (method == "setPosition") {
      double x = 40;
      double y = 40;
      if (const auto* args =
              std::get_if<flutter::EncodableMap>(call.arguments())) {
        auto ix = args->find(flutter::EncodableValue("x"));
        auto iy = args->find(flutter::EncodableValue("y"));
        if (ix != args->end()) {
          if (const auto* xd = std::get_if<double>(&ix->second)) {
            x = *xd;
          } else if (const auto* xi = std::get_if<int32_t>(&ix->second)) {
            x = *xi;
          }
        }
        if (iy != args->end()) {
          if (const auto* yd = std::get_if<double>(&iy->second)) {
            y = *yd;
          } else if (const auto* yi = std::get_if<int32_t>(&iy->second)) {
            y = *yi;
          }
        }
      }
      overlay_.setPosition(static_cast<int>(x), static_cast<int>(y));
      result->Success();
      return;
    }
    result->NotImplemented();
  }

private:
  OverlayWindow overlay_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

}  // namespace

void RegisterOverlayPlugin(flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "fluidvoice/overlay",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<OverlayPlugin>();
  auto* plugin_ptr = plugin.get();
  channel->SetMethodCallHandler(
      [plugin_ptr](const auto& call, auto result) {
        plugin_ptr->HandleMethodCall(call, std::move(result));
      });
  plugin_ptr->AttachChannel(std::move(channel));
  registrar->AddPlugin(std::move(plugin));
}
