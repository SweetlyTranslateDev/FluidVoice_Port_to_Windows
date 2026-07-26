#include "tray_plugin.h"

#include "tray_icon.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <vector>

namespace {

HWND g_appWindow = nullptr;
TrayIcon* g_tray = nullptr;

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

class TrayPlugin : public flutter::Plugin {
public:
  TrayPlugin() {
    g_tray = &tray_;
    tray_.setActionCallback([this](const std::string& id) {
      if (channel_) {
        channel_->InvokeMethod(
            "action",
            std::make_unique<flutter::EncodableValue>(id));
      }
    });
  }

  ~TrayPlugin() override {
    tray_.stop();
    if (g_tray == &tray_) {
      g_tray = nullptr;
    }
  }

  void AttachChannel(
      std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel) {
    channel_ = std::move(channel);
  }

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    const auto& method = call.method_name();
    if (method == "start") {
      const bool ok = tray_.start(g_appWindow);
      if (ok) {
        result->Success();
      } else {
        result->Error("tray_start_failed", "Shell_NotifyIcon failed");
      }
      return;
    }
    if (method == "stop") {
      tray_.stop();
      result->Success();
      return;
    }
    if (method == "setTooltip") {
      std::string tip = "FluidVoice";
      if (const auto* args =
              std::get_if<flutter::EncodableMap>(call.arguments())) {
        auto it = args->find(flutter::EncodableValue("text"));
        if (it != args->end()) {
          if (const auto* s = std::get_if<std::string>(&it->second)) {
            tip = *s;
          }
        }
      }
      tray_.setTooltip(Utf8ToWide(tip));
      result->Success();
      return;
    }
    if (method == "setStatus") {
      std::string status = "idle";
      if (const auto* args =
              std::get_if<flutter::EncodableMap>(call.arguments())) {
        auto it = args->find(flutter::EncodableValue("status"));
        if (it != args->end()) {
          if (const auto* s = std::get_if<std::string>(&it->second)) {
            status = *s;
          }
        }
      }
      std::wstring tip = L"FluidVoice";
      if (status == "listening") {
        tip = L"FluidVoice — Listening";
      } else if (status == "processing") {
        tip = L"FluidVoice — Processing";
      } else if (status == "error") {
        tip = L"FluidVoice — Error";
      } else {
        tip = L"FluidVoice — Idle";
      }
      tray_.setTooltip(tip);
      result->Success();
      return;
    }
    if (method == "setMenu") {
      std::vector<TrayMenuEntry> items;
      if (const auto* list =
              std::get_if<flutter::EncodableList>(call.arguments())) {
        for (const auto& entry : *list) {
          const auto* map = std::get_if<flutter::EncodableMap>(&entry);
          if (!map) {
            continue;
          }
          TrayMenuEntry item;
          auto idIt = map->find(flutter::EncodableValue("id"));
          auto labelIt = map->find(flutter::EncodableValue("label"));
          auto enIt = map->find(flutter::EncodableValue("enabled"));
          if (idIt != map->end()) {
            if (const auto* s = std::get_if<std::string>(&idIt->second)) {
              item.id = *s;
            }
          }
          if (labelIt != map->end()) {
            if (const auto* s = std::get_if<std::string>(&labelIt->second)) {
              item.label = Utf8ToWide(*s);
            }
          }
          item.enabled = true;
          if (enIt != map->end()) {
            if (const auto* b = std::get_if<bool>(&enIt->second)) {
              item.enabled = *b;
            }
          }
          if (!item.id.empty()) {
            items.push_back(std::move(item));
          }
        }
      }
      tray_.setMenu(std::move(items));
      result->Success();
      return;
    }
    if (method == "showApp") {
      tray_.showApp();
      result->Success();
      return;
    }
    if (method == "hideApp") {
      tray_.hideApp();
      result->Success();
      return;
    }
    if (method == "quitApp") {
      tray_.quitApp();
      result->Success();
      return;
    }
    result->NotImplemented();
  }

private:
  TrayIcon tray_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

}  // namespace

void TrayPluginSetAppWindow(HWND hwnd) { g_appWindow = hwnd; }

void RegisterTrayPlugin(flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "fluidvoice/tray",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<TrayPlugin>();
  auto* plugin_ptr = plugin.get();
  channel->SetMethodCallHandler(
      [plugin_ptr](const auto& call, auto result) {
        plugin_ptr->HandleMethodCall(call, std::move(result));
      });
  plugin_ptr->AttachChannel(std::move(channel));
  registrar->AddPlugin(std::move(plugin));
}
