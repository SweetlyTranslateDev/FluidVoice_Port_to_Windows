#pragma once

#include <windows.h>

#include <functional>
#include <mutex>
#include <string>
#include <vector>

struct TrayMenuEntry {
  std::string id;
  std::wstring label;
  bool enabled = true;
};

/**
 * Win32 Shell_NotifyIcon tray. Messages go to a message-only window.
 * No business logic — Dart decides menu actions.
 */
class TrayIcon {
public:
  using ActionCallback = std::function<void(const std::string& id)>;

  TrayIcon();
  ~TrayIcon();

  TrayIcon(const TrayIcon&) = delete;
  TrayIcon& operator=(const TrayIcon&) = delete;

  bool start(HWND appWindow);
  void stop();

  void setTooltip(const std::wstring& tip);
  void setMenu(std::vector<TrayMenuEntry> items);
  void setActionCallback(ActionCallback cb);

  void showApp();
  void hideApp();
  void quitApp();

  static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam,
                                  LPARAM lParam);

private:
  LRESULT handleMessage(UINT msg, WPARAM wParam, LPARAM lParam);
  void showContextMenu();
  void updateIcon();

  HWND m_hwnd = nullptr;
  HWND m_appWindow = nullptr;
  NOTIFYICONDATAW m_nid{};
  bool m_added = false;
  std::wstring m_tooltip = L"FluidVoice";
  std::vector<TrayMenuEntry> m_menu;
  ActionCallback m_callback;
  std::mutex m_mutex;
  UINT m_taskbarCreated = 0;
};
