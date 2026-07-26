#include "autostart_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <windows.h>

#include <memory>
#include <string>

namespace {

constexpr wchar_t kRunKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kValueName[] = L"FluidVoice";

std::wstring ExePath() {
  wchar_t path[MAX_PATH] = {};
  const DWORD n = GetModuleFileNameW(nullptr, path, MAX_PATH);
  if (n == 0 || n >= MAX_PATH) {
    return L"";
  }
  return path;
}

bool IsEnabled() {
  HKEY key = nullptr;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, kRunKey, 0, KEY_READ, &key) !=
      ERROR_SUCCESS) {
    return false;
  }
  wchar_t buf[MAX_PATH] = {};
  DWORD type = 0;
  DWORD size = sizeof(buf);
  const LONG rc =
      RegQueryValueExW(key, kValueName, nullptr, &type,
                       reinterpret_cast<LPBYTE>(buf), &size);
  RegCloseKey(key);
  return rc == ERROR_SUCCESS && type == REG_SZ && buf[0] != L'\0';
}

bool SetEnabled(bool enabled) {
  HKEY key = nullptr;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, kRunKey, 0, KEY_SET_VALUE, &key) !=
      ERROR_SUCCESS) {
    return false;
  }

  LONG rc;
  if (!enabled) {
    rc = RegDeleteValueW(key, kValueName);
    if (rc == ERROR_FILE_NOT_FOUND) {
      rc = ERROR_SUCCESS;
    }
  } else {
    const std::wstring path = ExePath();
    if (path.empty()) {
      RegCloseKey(key);
      return false;
    }
    // Quote path so spaces in Program Files are safe.
    std::wstring value = L"\"" + path + L"\"";
    rc = RegSetValueExW(
        key, kValueName, 0, REG_SZ,
        reinterpret_cast<const BYTE*>(value.c_str()),
        static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t)));
  }
  RegCloseKey(key);
  return rc == ERROR_SUCCESS;
}

class AutostartPlugin : public flutter::Plugin {
public:
  void AttachChannel(
      std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel) {
    channel_ = std::move(channel);
  }

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (call.method_name() == "isEnabled") {
      result->Success(flutter::EncodableValue(IsEnabled()));
      return;
    }
    if (call.method_name() == "setEnabled") {
      bool enabled = false;
      if (const auto* args =
              std::get_if<flutter::EncodableMap>(call.arguments())) {
        auto it = args->find(flutter::EncodableValue("enabled"));
        if (it != args->end()) {
          if (const auto* b = std::get_if<bool>(&it->second)) {
            enabled = *b;
          }
        }
      }
      if (SetEnabled(enabled)) {
        result->Success(flutter::EncodableValue(true));
      } else {
        result->Error("autostart_failed", "Could not update Run registry key");
      }
      return;
    }
    result->NotImplemented();
  }

private:
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

}  // namespace

void RegisterAutostartPlugin(flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "fluidvoice/autostart",
          &flutter::StandardMethodCodec::GetInstance());
  auto plugin = std::make_unique<AutostartPlugin>();
  auto* plugin_ptr = plugin.get();
  channel->SetMethodCallHandler(
      [plugin_ptr](const auto& call, auto result) {
        plugin_ptr->HandleMethodCall(call, std::move(result));
      });
  plugin_ptr->AttachChannel(std::move(channel));
  registrar->AddPlugin(std::move(plugin));
}
