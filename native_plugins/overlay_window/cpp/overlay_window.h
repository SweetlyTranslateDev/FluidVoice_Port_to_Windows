#pragma once

#include <windows.h>

#include <mutex>
#include <string>

/**
 * Frameless always-on-top transcript overlay (no Flutter engine).
 * Controlled from Dart via MethodChannel — no audio on this path.
 */
class OverlayWindow {
public:
  OverlayWindow();
  ~OverlayWindow();

  OverlayWindow(const OverlayWindow&) = delete;
  OverlayWindow& operator=(const OverlayWindow&) = delete;

  bool create();
  void destroy();
  void show();
  void hide();
  void setTranscript(const std::wstring& text);
  void setClickThrough(bool enabled);
  void setPosition(int x, int y);

  static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam,
                                  LPARAM lParam);

private:
  LRESULT handleMessage(UINT msg, WPARAM wParam, LPARAM lParam);
  void paint(HDC hdc);
  void applyClickThrough();
  void layoutToContent();

  HWND m_hwnd = nullptr;
  std::wstring m_text;
  bool m_clickThrough = true;
  bool m_visible = false;
  int m_x = 40;
  int m_y = 40;
  std::mutex m_mutex;
};
