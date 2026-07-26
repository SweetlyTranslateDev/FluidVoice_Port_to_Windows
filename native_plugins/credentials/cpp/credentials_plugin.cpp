#include "credentials_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <windows.h>
#include <wincred.h>

#include <memory>
#include <string>
#include <vector>

#pragma comment(lib, "Advapi32.lib")

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

std::wstring TargetName(const std::string& key) {
  return L"FluidVoice/" + Utf8ToWide(key);
}

bool WriteSecret(const std::string& key, const std::string& value) {
  if (key.empty()) {
    return false;
  }
  const std::wstring target = TargetName(key);
  CREDENTIALW cred = {};
  cred.Type = CRED_TYPE_GENERIC;
  cred.TargetName = const_cast<LPWSTR>(target.c_str());
  cred.CredentialBlobSize = static_cast<DWORD>(value.size());
  cred.CredentialBlob =
      reinterpret_cast<LPBYTE>(const_cast<char*>(value.data()));
  cred.Persist = CRED_PERSIST_LOCAL_MACHINE;
  cred.UserName = const_cast<LPWSTR>(L"FluidVoice");
  return CredWriteW(&cred, 0) == TRUE;
}

bool ReadSecret(const std::string& key, std::string* out) {
  out->clear();
  if (key.empty()) {
    return false;
  }
  const std::wstring target = TargetName(key);
  PCREDENTIALW cred = nullptr;
  if (!CredReadW(target.c_str(), CRED_TYPE_GENERIC, 0, &cred) || !cred) {
    return false;
  }
  if (cred->CredentialBlob && cred->CredentialBlobSize > 0) {
    out->assign(reinterpret_cast<char*>(cred->CredentialBlob),
                cred->CredentialBlobSize);
  }
  CredFree(cred);
  return true;
}

bool DeleteSecret(const std::string& key) {
  if (key.empty()) {
    return false;
  }
  const std::wstring target = TargetName(key);
  if (CredDeleteW(target.c_str(), CRED_TYPE_GENERIC, 0)) {
    return true;
  }
  return GetLastError() == ERROR_NOT_FOUND;
}

std::string ArgString(const flutter::EncodableMap* args, const char* key) {
  if (!args) {
    return "";
  }
  auto it = args->find(flutter::EncodableValue(key));
  if (it == args->end()) {
    return "";
  }
  if (const auto* s = std::get_if<std::string>(&it->second)) {
    return *s;
  }
  return "";
}

class CredentialsPlugin : public flutter::Plugin {
public:
  void AttachChannel(
      std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel) {
    channel_ = std::move(channel);
  }

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (call.method_name() == "write") {
      const auto key = ArgString(args, "key");
      const auto value = ArgString(args, "value");
      if (WriteSecret(key, value)) {
        result->Success();
      } else {
        result->Error("cred_write_failed", "CredWrite failed");
      }
      return;
    }
    if (call.method_name() == "read") {
      const auto key = ArgString(args, "key");
      std::string value;
      if (ReadSecret(key, &value)) {
        result->Success(flutter::EncodableValue(value));
      } else {
        result->Success(flutter::EncodableValue());  // null
      }
      return;
    }
    if (call.method_name() == "delete") {
      const auto key = ArgString(args, "key");
      if (DeleteSecret(key)) {
        result->Success();
      } else {
        result->Error("cred_delete_failed", "CredDelete failed");
      }
      return;
    }
    result->NotImplemented();
  }

private:
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

}  // namespace

void RegisterCredentialsPlugin(flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "fluidvoice/credentials",
          &flutter::StandardMethodCodec::GetInstance());
  auto plugin = std::make_unique<CredentialsPlugin>();
  auto* plugin_ptr = plugin.get();
  channel->SetMethodCallHandler(
      [plugin_ptr](const auto& call, auto result) {
        plugin_ptr->HandleMethodCall(call, std::move(result));
      });
  plugin_ptr->AttachChannel(std::move(channel));
  registrar->AddPlugin(std::move(plugin));
}
