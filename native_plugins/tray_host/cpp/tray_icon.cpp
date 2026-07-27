#include "tray_icon.h"

#include <shellapi.h>

#include <cstring>

// Match runner/resource.h — FluidVoice app icon.
#ifndef IDI_APP_ICON
#define IDI_APP_ICON 101
#endif

namespace {
constexpr wchar_t kClassName[] = L"FluidVoiceTrayHost";
constexpr UINT kTrayMsg = WM_APP + 40;
constexpr UINT kCmdBase = 4000;

HICON LoadTrayIcon() {
  const int cx = GetSystemMetrics(SM_CXSMICON);
  const int cy = GetSystemMetrics(SM_CYSMICON);
  HINSTANCE inst = GetModuleHandleW(nullptr);

  // Avoid variable names like `icon` / `small` — Windows headers macro those.
  HICON loaded = static_cast<HICON>(LoadImageW(
      inst, MAKEINTRESOURCEW(IDI_APP_ICON), IMAGE_ICON, cx, cy,
      LR_DEFAULTCOLOR));
  if (loaded != nullptr) {
    return loaded;
  }

  // Fallback: extract small icon from this EXE.
  wchar_t path[MAX_PATH] = {};
  if (GetModuleFileNameW(inst, path, MAX_PATH) > 0) {
    HICON largeIcon = nullptr;
    HICON smallIcon = nullptr;
    if (ExtractIconExW(path, 0, &largeIcon, &smallIcon, 1) > 0) {
      if (largeIcon != nullptr) {
        DestroyIcon(largeIcon);
      }
      if (smallIcon != nullptr) {
        return smallIcon;
      }
    }
  }

  return LoadIconW(nullptr, IDI_APPLICATION);
}

void EnsureClass() {
  static bool registered = false;
  if (registered) {
    return;
  }
  WNDCLASSEXW wc = {};
  wc.cbSize = sizeof(wc);
  wc.lpfnWndProc = TrayIcon::WndProc;
  wc.hInstance = GetModuleHandleW(nullptr);
  wc.lpszClassName = kClassName;
  RegisterClassExW(&wc);
  registered = true;
}
}  // namespace

TrayIcon::TrayIcon() {
  m_taskbarCreated = RegisterWindowMessageW(L"TaskbarCreated");
}

TrayIcon::~TrayIcon() { stop(); }

bool TrayIcon::start(HWND appWindow) {
  std::lock_guard<std::mutex> lock(m_mutex);
  m_appWindow = appWindow;
  if (m_added) {
    return true;
  }
  EnsureClass();
  m_hwnd = CreateWindowExW(0, kClassName, L"", 0, 0, 0, 0, 0, HWND_MESSAGE,
                           nullptr, GetModuleHandleW(nullptr), this);
  if (!m_hwnd) {
    return false;
  }

  ZeroMemory(&m_nid, sizeof(m_nid));
  m_nid.cbSize = sizeof(m_nid);
  m_nid.hWnd = m_hwnd;
  m_nid.uID = 1;
  m_nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP | NIF_SHOWTIP;
  m_nid.uCallbackMessage = kTrayMsg;
  m_nid.hIcon = LoadTrayIcon();
  wcsncpy_s(m_nid.szTip, m_tooltip.c_str(), _TRUNCATE);

  if (!Shell_NotifyIconW(NIM_ADD, &m_nid)) {
    DestroyWindow(m_hwnd);
    m_hwnd = nullptr;
    return false;
  }
  m_nid.uVersion = NOTIFYICON_VERSION_4;
  Shell_NotifyIconW(NIM_SETVERSION, &m_nid);
  m_added = true;
  return true;
}

void TrayIcon::stop() {
  std::lock_guard<std::mutex> lock(m_mutex);
  if (m_added) {
    Shell_NotifyIconW(NIM_DELETE, &m_nid);
    m_added = false;
  }
  if (m_hwnd) {
    DestroyWindow(m_hwnd);
    m_hwnd = nullptr;
  }
}

void TrayIcon::setTooltip(const std::wstring& tip) {
  std::lock_guard<std::mutex> lock(m_mutex);
  m_tooltip = tip.empty() ? L"FluidVoice" : tip;
  if (!m_added) {
    return;
  }
  wcsncpy_s(m_nid.szTip, m_tooltip.c_str(), _TRUNCATE);
  Shell_NotifyIconW(NIM_MODIFY, &m_nid);
}

void TrayIcon::setMenu(std::vector<TrayMenuEntry> items) {
  std::lock_guard<std::mutex> lock(m_mutex);
  m_menu = std::move(items);
}

void TrayIcon::setActionCallback(ActionCallback cb) {
  std::lock_guard<std::mutex> lock(m_mutex);
  m_callback = std::move(cb);
}

void TrayIcon::showApp() {
  HWND app = nullptr;
  {
    std::lock_guard<std::mutex> lock(m_mutex);
    app = m_appWindow;
  }
  if (!app || !IsWindow(app)) {
    return;
  }
  ShowWindow(app, SW_SHOW);
  ShowWindow(app, SW_RESTORE);
  SetForegroundWindow(app);
}

void TrayIcon::hideApp() {
  HWND app = nullptr;
  {
    std::lock_guard<std::mutex> lock(m_mutex);
    app = m_appWindow;
  }
  if (app && IsWindow(app)) {
    ShowWindow(app, SW_HIDE);
  }
}

void TrayIcon::quitApp() {
  HWND app = nullptr;
  {
    std::lock_guard<std::mutex> lock(m_mutex);
    app = m_appWindow;
  }
  stop();
  if (app && IsWindow(app)) {
    DestroyWindow(app);
  }
  PostQuitMessage(0);
}

void TrayIcon::updateIcon() {
  if (!m_added) {
    return;
  }
  wcsncpy_s(m_nid.szTip, m_tooltip.c_str(), _TRUNCATE);
  Shell_NotifyIconW(NIM_MODIFY, &m_nid);
}

void TrayIcon::showContextMenu() {
  std::vector<TrayMenuEntry> menu;
  ActionCallback cb;
  {
    std::lock_guard<std::mutex> lock(m_mutex);
    menu = m_menu;
    cb = m_callback;
  }
  if (menu.empty()) {
    menu.push_back({"show", L"Show FluidVoice", true});
    menu.push_back({"quit", L"Quit", true});
  }

  HMENU hMenu = CreatePopupMenu();
  for (size_t i = 0; i < menu.size(); ++i) {
    UINT flags = MF_STRING;
    if (!menu[i].enabled) {
      flags |= MF_GRAYED;
    }
    AppendMenuW(hMenu, flags, kCmdBase + static_cast<UINT>(i),
                menu[i].label.c_str());
  }

  POINT pt;
  GetCursorPos(&pt);
  SetForegroundWindow(m_hwnd);
  const UINT cmd = TrackPopupMenu(hMenu, TPM_RETURNCMD | TPM_NONOTIFY,
                                  pt.x, pt.y, 0, m_hwnd, nullptr);
  DestroyMenu(hMenu);
  PostMessageW(m_hwnd, WM_NULL, 0, 0);

  if (cmd >= kCmdBase && cmd < kCmdBase + menu.size()) {
    const auto& id = menu[cmd - kCmdBase].id;
    if (id == "show") {
      showApp();
    } else if (id == "quit") {
      quitApp();
      return;
    }
    if (cb) {
      cb(id);
    }
  }
}

LRESULT CALLBACK TrayIcon::WndProc(HWND hwnd, UINT msg, WPARAM wParam,
                                   LPARAM lParam) {
  TrayIcon* self = nullptr;
  if (msg == WM_NCCREATE) {
    auto* cs = reinterpret_cast<CREATESTRUCTW*>(lParam);
    self = static_cast<TrayIcon*>(cs->lpCreateParams);
    SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
  } else {
    self = reinterpret_cast<TrayIcon*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
  }
  if (self) {
    return self->handleMessage(msg, wParam, lParam);
  }
  return DefWindowProcW(hwnd, msg, wParam, lParam);
}

LRESULT TrayIcon::handleMessage(UINT msg, WPARAM wParam, LPARAM lParam) {
  if (m_taskbarCreated && msg == m_taskbarCreated) {
    std::lock_guard<std::mutex> lock(m_mutex);
    if (m_hwnd) {
      m_added = false;
      Shell_NotifyIconW(NIM_ADD, &m_nid);
      m_nid.uVersion = NOTIFYICON_VERSION_4;
      Shell_NotifyIconW(NIM_SETVERSION, &m_nid);
      m_added = true;
    }
    return 0;
  }

  if (msg == kTrayMsg) {
    switch (LOWORD(lParam)) {
      case WM_LBUTTONUP:
      case NIN_SELECT:
        showApp();
        if (m_callback) {
          m_callback("show");
        }
        break;
      case WM_RBUTTONUP:
      case WM_CONTEXTMENU:
        showContextMenu();
        break;
      default:
        break;
    }
    return 0;
  }

  if (msg == WM_DESTROY) {
    return 0;
  }
  return DefWindowProcW(m_hwnd, msg, wParam, lParam);
}
