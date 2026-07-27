#include "window_chrome_plugin.h"

#include <dwmapi.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>

#pragma comment(lib, "dwmapi.lib")

namespace {

#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif
#ifndef DWMWA_SYSTEMBACKDROP_TYPE
#define DWMWA_SYSTEMBACKDROP_TYPE 38
#endif
#ifndef DWMWA_CAPTION_COLOR
#define DWMWA_CAPTION_COLOR 35
#endif
#ifndef DWMSBT_NONE
#define DWMSBT_NONE 1
#endif
#ifndef DWMSBT_MAINWINDOW
#define DWMSBT_MAINWINDOW 2
#endif
#ifndef DWMSBT_TRANSIENTWINDOW
#define DWMSBT_TRANSIENTWINDOW 3
#endif
#ifndef DWMWA_MICA_EFFECT
#define DWMWA_MICA_EFFECT 1029
#endif

typedef enum _WINDOWCOMPOSITIONATTRIB {
  WCA_ACCENT_POLICY = 19,
} WINDOWCOMPOSITIONATTRIB;

typedef struct _WINDOWCOMPOSITIONATTRIBDATA {
  WINDOWCOMPOSITIONATTRIB Attrib;
  PVOID pvData;
  SIZE_T cbData;
} WINDOWCOMPOSITIONATTRIBDATA;

typedef enum _ACCENT_STATE {
  ACCENT_DISABLED = 0,
  ACCENT_ENABLE_GRADIENT = 1,
  ACCENT_ENABLE_TRANSPARENTGRADIENT = 2,
  ACCENT_ENABLE_BLURBEHIND = 3,
  ACCENT_ENABLE_ACRYLICBLURBEHIND = 4,
  ACCENT_ENABLE_HOSTBACKDROP = 5,
} ACCENT_STATE;

typedef struct _ACCENT_POLICY {
  ACCENT_STATE AccentState;
  DWORD AccentFlags;
  DWORD GradientColor;
  DWORD AnimationId;
} ACCENT_POLICY;

typedef BOOL(WINAPI* SetWindowCompositionAttributeFn)(
    HWND, WINDOWCOMPOSITIONATTRIBDATA*);

typedef LONG NTSTATUS;
typedef NTSTATUS(WINAPI* RtlGetVersionPtr)(PRTL_OSVERSIONINFOW);

HWND g_app_window = nullptr;
SetWindowCompositionAttributeFn g_set_window_composition_attribute = nullptr;

void EnsureCompositionApi() {
  if (g_set_window_composition_attribute != nullptr) {
    return;
  }
  HMODULE user32 = ::GetModuleHandleW(L"user32.dll");
  if (user32 == nullptr) {
    return;
  }
  g_set_window_composition_attribute =
      reinterpret_cast<SetWindowCompositionAttributeFn>(
          ::GetProcAddress(user32, "SetWindowCompositionAttribute"));
}

DWORD GetWindowsBuildNumber() {
  HMODULE ntdll = ::GetModuleHandleW(L"ntdll.dll");
  if (ntdll == nullptr) {
    return 0;
  }
  auto rtl_get_version = reinterpret_cast<RtlGetVersionPtr>(
      ::GetProcAddress(ntdll, "RtlGetVersion"));
  if (rtl_get_version == nullptr) {
    return 0;
  }
  RTL_OSVERSIONINFOW info = {};
  info.dwOSVersionInfoSize = sizeof(info);
  if (rtl_get_version(&info) != 0) {
    return 0;
  }
  return info.dwBuildNumber;
}

HWND ResolveAppWindow() {
  if (g_app_window != nullptr && ::IsWindow(g_app_window)) {
    return g_app_window;
  }
  return nullptr;
}

bool ReadBool(const flutter::EncodableMap& args, const char* key, bool fallback) {
  auto it = args.find(flutter::EncodableValue(key));
  if (it == args.end()) {
    return fallback;
  }
  if (const auto* b = std::get_if<bool>(&it->second)) {
    return *b;
  }
  return fallback;
}

int32_t ReadInt(const flutter::EncodableMap& args, const char* key, int32_t fallback) {
  auto it = args.find(flutter::EncodableValue(key));
  if (it == args.end()) {
    return fallback;
  }
  if (const auto* i = std::get_if<int32_t>(&it->second)) {
    return *i;
  }
  if (const auto* i64 = std::get_if<int64_t>(&it->second)) {
    return static_cast<int32_t>(*i64);
  }
  return fallback;
}

void SetAccentDisabled(HWND hwnd) {
  EnsureCompositionApi();
  if (g_set_window_composition_attribute == nullptr) {
    return;
  }
  ACCENT_POLICY accent = {ACCENT_DISABLED, 2, 0, 0};
  WINDOWCOMPOSITIONATTRIBDATA data = {WCA_ACCENT_POLICY, &accent,
                                      sizeof(accent)};
  g_set_window_composition_attribute(hwnd, &data);
}

void ApplyAlwaysOnTop(bool enabled) {
  HWND hwnd = ResolveAppWindow();
  if (hwnd == nullptr) {
    return;
  }
  ::SetWindowPos(hwnd, enabled ? HWND_TOPMOST : HWND_NOTOPMOST, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
}

// Tint is Windows ABGR (A << 24 | B << 16 | G << 8 | R).
void ApplyAcrylic(bool enabled, DWORD tint_abgr) {
  HWND hwnd = ResolveAppWindow();
  if (hwnd == nullptr) {
    return;
  }

  EnsureCompositionApi();
  const DWORD build = GetWindowsBuildNumber();

  // Reset composition so style switches apply cleanly.
  SetAccentDisabled(hwnd);

  if (!enabled) {
    BOOL dark = FALSE;
    BOOL mica = FALSE;
    INT none = DWMSBT_NONE;
    MARGINS margins = {0, 0, 1, 0};
    ::DwmExtendFrameIntoClientArea(hwnd, &margins);
    ::DwmSetWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, &none,
                            sizeof(none));
    ::DwmSetWindowAttribute(hwnd, DWMWA_MICA_EFFECT, &mica, sizeof(mica));
    ::DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, &dark,
                            sizeof(dark));
    return;
  }

  BOOL dark = TRUE;
  ::DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, &dark,
                          sizeof(dark));

  // Win11 22523+: official acrylic/mica system backdrop.
  if (build >= 22523) {
    MARGINS margins = {-1};
    ::DwmExtendFrameIntoClientArea(hwnd, &margins);
    COLORREF caption_none = 0xFFFFFFFE;
    ::DwmSetWindowAttribute(hwnd, DWMWA_CAPTION_COLOR, &caption_none,
                            sizeof(caption_none));
    INT effect = DWMSBT_TRANSIENTWINDOW;  // acrylic
    ::DwmSetWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, &effect,
                            sizeof(effect));
  } else if (build >= 22000) {
    // Early Win11: mica attribute + sheet-of-glass margins.
    BOOL enable = TRUE;
    MARGINS margins = {-1};
    ::DwmExtendFrameIntoClientArea(hwnd, &margins);
    ::DwmSetWindowAttribute(hwnd, DWMWA_MICA_EFFECT, &enable, sizeof(enable));
  }

  // Accent acrylic works on Win10 1803+ and also helps Flutter show blur
  // through translucent surfaces on Win11.
  if (g_set_window_composition_attribute != nullptr) {
    ACCENT_POLICY accent = {ACCENT_ENABLE_ACRYLICBLURBEHIND, 2, tint_abgr, 0};
    WINDOWCOMPOSITIONATTRIBDATA data = {WCA_ACCENT_POLICY, &accent,
                                        sizeof(accent)};
    g_set_window_composition_attribute(hwnd, &data);
  }
}

class WindowChromePlugin : public flutter::Plugin {
 public:
  explicit WindowChromePlugin(flutter::PluginRegistrarWindows* registrar)
      : registrar_(registrar) {}

  void AttachChannel(
      std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
          channel) {
    channel_ = std::move(channel);
  }

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    // Prefer the live Flutter host HWND if available.
    if (registrar_ != nullptr && registrar_->GetView() != nullptr) {
      HWND view = registrar_->GetView()->GetNativeWindow();
      if (view != nullptr) {
        HWND root = ::GetAncestor(view, GA_ROOT);
        if (root != nullptr) {
          g_app_window = root;
        }
      }
    }

    if (call.method_name() == "setAlwaysOnTop") {
      bool enabled = false;
      if (const auto* args =
              std::get_if<flutter::EncodableMap>(call.arguments())) {
        enabled = ReadBool(*args, "enabled", false);
      }
      ApplyAlwaysOnTop(enabled);
      result->Success(flutter::EncodableValue(true));
      return;
    }

    if (call.method_name() == "setAcrylic") {
      bool enabled = false;
      // Default tint: dark translucent (A=0xCC, BGR ≈ #171717)
      DWORD tint = 0xCC171717;
      if (const auto* args =
              std::get_if<flutter::EncodableMap>(call.arguments())) {
        enabled = ReadBool(*args, "enabled", false);
        const int a = ReadInt(*args, "a", 0xCC);
        const int r = ReadInt(*args, "r", 0x17);
        const int g = ReadInt(*args, "g", 0x17);
        const int b = ReadInt(*args, "b", 0x17);
        tint = (static_cast<DWORD>(a & 0xFF) << 24) |
               (static_cast<DWORD>(b & 0xFF) << 16) |
               (static_cast<DWORD>(g & 0xFF) << 8) |
               (static_cast<DWORD>(r & 0xFF));
      }
      ApplyAcrylic(enabled, tint);
      result->Success(flutter::EncodableValue(true));
      return;
    }

    result->NotImplemented();
  }

 private:
  flutter::PluginRegistrarWindows* registrar_ = nullptr;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

}  // namespace

void WindowChromePluginSetAppWindow(HWND hwnd) { g_app_window = hwnd; }

void RegisterWindowChromePlugin(flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<WindowChromePlugin>(registrar);
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
