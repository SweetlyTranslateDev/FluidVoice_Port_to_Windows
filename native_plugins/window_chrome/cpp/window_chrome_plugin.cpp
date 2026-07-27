#include "window_chrome_plugin.h"

#include <dwmapi.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <optional>

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

HWND g_app_window = nullptr;
SetWindowCompositionAttributeFn g_set_window_composition_attribute = nullptr;
bool g_acrylic_enabled = false;
DWORD g_acrylic_tint_abgr = 0x99101010;
bool g_minimize_to_tray = false;

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

int32_t ReadInt(const flutter::EncodableMap& args, const char* key,
                int32_t fallback) {
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

void ClearSystemBackdrop(HWND hwnd) {
  INT none = DWMSBT_NONE;
  ::DwmSetWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, &none, sizeof(none));
  BOOL mica = FALSE;
  ::DwmSetWindowAttribute(hwnd, DWMWA_MICA_EFFECT, &mica, sizeof(mica));
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
//
// Uses accent acrylic/blur on the whole window so translucent Flutter pixels
// can show the desktop. Avoids Win11 SYSTEMBACKDROP acrylic, which only tints
// the chrome (blue when focused, nearly solid when inactive) while the Flutter
// surface stays opaque.
void ApplyAcrylic(bool enabled, DWORD tint_abgr) {
  HWND hwnd = ResolveAppWindow();
  if (hwnd == nullptr) {
    return;
  }

  g_acrylic_enabled = enabled;
  g_acrylic_tint_abgr = tint_abgr;

  EnsureCompositionApi();
  ClearSystemBackdrop(hwnd);

  if (!enabled) {
    SetAccentDisabled(hwnd);
    MARGINS margins = {0, 0, 1, 0};
    ::DwmExtendFrameIntoClientArea(hwnd, &margins);
    BOOL dark = TRUE;
    ::DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, &dark,
                            sizeof(dark));
    return;
  }

  BOOL dark = TRUE;
  ::DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, &dark,
                          sizeof(dark));

  // Sheet-of-glass: lets DWM composite under translucent Flutter content.
  MARGINS margins = {-1};
  ::DwmExtendFrameIntoClientArea(hwnd, &margins);

  if (g_set_window_composition_attribute == nullptr) {
    return;
  }

  // Acrylic blurbehind (Win10 1803+ / Win11). Tint alpha controls wash strength.
  ACCENT_POLICY accent = {ACCENT_ENABLE_ACRYLICBLURBEHIND, 2, tint_abgr, 0};
  WINDOWCOMPOSITIONATTRIBDATA data = {WCA_ACCENT_POLICY, &accent,
                                      sizeof(accent)};
  g_set_window_composition_attribute(hwnd, &data);
}

void ReapplyAcrylicIfNeeded() {
  if (!g_acrylic_enabled) {
    return;
  }
  ApplyAcrylic(true, g_acrylic_tint_abgr);
}

class WindowChromePlugin : public flutter::Plugin {
 public:
  explicit WindowChromePlugin(flutter::PluginRegistrarWindows* registrar)
      : registrar_(registrar) {
    window_proc_id_ = registrar_->RegisterTopLevelWindowProcDelegate(
        [this](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
          return HandleWindowProc(hwnd, message, wparam, lparam);
        });
  }

  ~WindowChromePlugin() override {
    if (registrar_ != nullptr && window_proc_id_ != 0) {
      registrar_->UnregisterTopLevelWindowProcDelegate(window_proc_id_);
    }
  }

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
      // Default: dark wash, ~60% alpha so desktop blur remains visible.
      DWORD tint = 0x99101010;
      if (const auto* args =
              std::get_if<flutter::EncodableMap>(call.arguments())) {
        enabled = ReadBool(*args, "enabled", false);
        const int a = ReadInt(*args, "a", 0x99);
        const int r = ReadInt(*args, "r", 0x10);
        const int g = ReadInt(*args, "g", 0x10);
        const int b = ReadInt(*args, "b", 0x10);
        tint = (static_cast<DWORD>(a & 0xFF) << 24) |
               (static_cast<DWORD>(b & 0xFF) << 16) |
               (static_cast<DWORD>(g & 0xFF) << 8) |
               (static_cast<DWORD>(r & 0xFF));
      }
      ApplyAcrylic(enabled, tint);
      result->Success(flutter::EncodableValue(true));
      return;
    }

    if (call.method_name() == "setMinimizeToTray") {
      bool enabled = false;
      if (const auto* args =
              std::get_if<flutter::EncodableMap>(call.arguments())) {
        enabled = ReadBool(*args, "enabled", false);
      }
      g_minimize_to_tray = enabled;
      result->Success(flutter::EncodableValue(true));
      return;
    }

    result->NotImplemented();
  }

 private:
  std::optional<LRESULT> HandleWindowProc(HWND hwnd, UINT message,
                                          WPARAM wparam, LPARAM /*lparam*/) {
    if (message == WM_SYSCOMMAND &&
        (wparam & 0xFFF0) == SC_MINIMIZE && g_minimize_to_tray) {
      // Hide to tray instead of taskbar minimize.
      ::ShowWindow(hwnd, SW_HIDE);
      return 0;
    }
    if (message == WM_ACTIVATE) {
      // Re-apply after focus changes; Windows often drops accent blur.
      if (LOWORD(wparam) != WA_INACTIVE) {
        ReapplyAcrylicIfNeeded();
      }
    } else if (message == WM_DWMCOMPOSITIONCHANGED ||
               message == WM_DWMCOLORIZATIONCOLORCHANGED) {
      ReapplyAcrylicIfNeeded();
    }
    return std::nullopt;
  }

  flutter::PluginRegistrarWindows* registrar_ = nullptr;
  int window_proc_id_ = 0;
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
