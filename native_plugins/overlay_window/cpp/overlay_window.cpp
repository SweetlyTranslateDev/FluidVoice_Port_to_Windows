#include "overlay_window.h"

#include <algorithm>
#include <string>

namespace {
constexpr wchar_t kClassName[] = L"FluidVoiceOverlayWindow";
constexpr int kPadX = 20;
constexpr int kPadY = 14;
constexpr int kMaxWidth = 720;
constexpr int kMinWidth = 220;
constexpr int kFontPx = 18;

void EnsureClass() {
  static bool registered = false;
  if (registered) {
    return;
  }
  WNDCLASSEXW wc = {};
  wc.cbSize = sizeof(wc);
  wc.lpfnWndProc = OverlayWindow::WndProc;
  wc.hInstance = GetModuleHandleW(nullptr);
  wc.lpszClassName = kClassName;
  wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
  RegisterClassExW(&wc);
  registered = true;
}
}  // namespace

OverlayWindow::OverlayWindow() = default;

OverlayWindow::~OverlayWindow() { destroy(); }

bool OverlayWindow::create() {
  std::lock_guard<std::mutex> lock(m_mutex);
  if (m_hwnd) {
    return true;
  }
  EnsureClass();
  m_hwnd = CreateWindowExW(
      WS_EX_LAYERED | WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
      kClassName, L"FluidVoice Overlay", WS_POPUP, m_x, m_y, kMinWidth, 48,
      nullptr, nullptr, GetModuleHandleW(nullptr), this);
  if (!m_hwnd) {
    return false;
  }
  SetLayeredWindowAttributes(m_hwnd, 0, 230, LWA_ALPHA);
  applyClickThrough();
  return true;
}

void OverlayWindow::destroy() {
  std::lock_guard<std::mutex> lock(m_mutex);
  if (m_hwnd) {
    DestroyWindow(m_hwnd);
    m_hwnd = nullptr;
  }
}

void OverlayWindow::show() {
  if (!create()) {
    return;
  }
  std::lock_guard<std::mutex> lock(m_mutex);
  m_visible = true;
  layoutToContent();
  ShowWindow(m_hwnd, SW_SHOWNOACTIVATE);
  SetWindowPos(m_hwnd, HWND_TOPMOST, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
}

void OverlayWindow::hide() {
  std::lock_guard<std::mutex> lock(m_mutex);
  m_visible = false;
  if (m_hwnd) {
    ShowWindow(m_hwnd, SW_HIDE);
  }
}

void OverlayWindow::setTranscript(const std::wstring& text) {
  std::lock_guard<std::mutex> lock(m_mutex);
  m_text = text;
  if (m_hwnd) {
    layoutToContent();
    InvalidateRect(m_hwnd, nullptr, TRUE);
  }
}

void OverlayWindow::setClickThrough(bool enabled) {
  std::lock_guard<std::mutex> lock(m_mutex);
  m_clickThrough = enabled;
  applyClickThrough();
}

void OverlayWindow::setPosition(int x, int y) {
  std::lock_guard<std::mutex> lock(m_mutex);
  m_x = x;
  m_y = y;
  if (m_hwnd) {
    SetWindowPos(m_hwnd, HWND_TOPMOST, m_x, m_y, 0, 0,
                 SWP_NOSIZE | SWP_NOACTIVATE);
  }
}

void OverlayWindow::applyClickThrough() {
  if (!m_hwnd) {
    return;
  }
  LONG_PTR ex = GetWindowLongPtrW(m_hwnd, GWL_EXSTYLE);
  if (m_clickThrough) {
    ex |= WS_EX_TRANSPARENT;
  } else {
    ex &= ~WS_EX_TRANSPARENT;
  }
  SetWindowLongPtrW(m_hwnd, GWL_EXSTYLE, ex);
}

void OverlayWindow::layoutToContent() {
  if (!m_hwnd) {
    return;
  }
  HDC hdc = GetDC(m_hwnd);
  HFONT font = CreateFontW(kFontPx, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
                           DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
                           CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                           DEFAULT_PITCH | FF_SWISS, L"Segoe UI");
  HFONT old = static_cast<HFONT>(SelectObject(hdc, font));
  RECT rc = {0, 0, kMaxWidth - 2 * kPadX, 0};
  const std::wstring& draw =
      m_text.empty() ? std::wstring(L"Listening…") : m_text;
  DrawTextW(hdc, draw.c_str(), static_cast<int>(draw.size()), &rc,
            DT_WORDBREAK | DT_CALCRECT);
  SelectObject(hdc, old);
  DeleteObject(font);
  ReleaseDC(m_hwnd, hdc);

  const int contentW = static_cast<int>(rc.right) + 2 * kPadX;
  const int contentH = static_cast<int>(rc.bottom) + 2 * kPadY;
  const int width =
      contentW < kMinWidth ? kMinWidth : (contentW > kMaxWidth ? kMaxWidth : contentW);
  const int height = contentH < 48 ? 48 : contentH;
  SetWindowPos(m_hwnd, HWND_TOPMOST, m_x, m_y, width, height,
               SWP_NOACTIVATE);
}

void OverlayWindow::paint(HDC hdc) {
  RECT client{};
  GetClientRect(m_hwnd, &client);

  HBRUSH brush = CreateSolidBrush(RGB(28, 28, 30));
  FillRect(hdc, &client, brush);
  DeleteObject(brush);

  HFONT font = CreateFontW(kFontPx, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
                           DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
                           CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                           DEFAULT_PITCH | FF_SWISS, L"Segoe UI");
  HFONT old = static_cast<HFONT>(SelectObject(hdc, font));
  SetBkMode(hdc, TRANSPARENT);
  SetTextColor(hdc, RGB(245, 245, 247));
  RECT textRc = client;
  textRc.left += kPadX;
  textRc.right -= kPadX;
  textRc.top += kPadY;
  textRc.bottom -= kPadY;
  const std::wstring& draw =
      m_text.empty() ? std::wstring(L"Listening…") : m_text;
  DrawTextW(hdc, draw.c_str(), static_cast<int>(draw.size()), &textRc,
            DT_WORDBREAK | DT_LEFT | DT_TOP);
  SelectObject(hdc, old);
  DeleteObject(font);
}

LRESULT CALLBACK OverlayWindow::WndProc(HWND hwnd, UINT msg, WPARAM wParam,
                                        LPARAM lParam) {
  OverlayWindow* self = nullptr;
  if (msg == WM_NCCREATE) {
    auto* cs = reinterpret_cast<CREATESTRUCTW*>(lParam);
    self = static_cast<OverlayWindow*>(cs->lpCreateParams);
    SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
    self->m_hwnd = hwnd;
  } else {
    self = reinterpret_cast<OverlayWindow*>(
        GetWindowLongPtrW(hwnd, GWLP_USERDATA));
  }
  if (self) {
    return self->handleMessage(msg, wParam, lParam);
  }
  return DefWindowProcW(hwnd, msg, wParam, lParam);
}

LRESULT OverlayWindow::handleMessage(UINT msg, WPARAM wParam, LPARAM lParam) {
  switch (msg) {
    case WM_PAINT: {
      PAINTSTRUCT ps;
      HDC hdc = BeginPaint(m_hwnd, &ps);
      paint(hdc);
      EndPaint(m_hwnd, &ps);
      return 0;
    }
    case WM_ERASEBKGND:
      return 1;
    case WM_NCHITTEST:
      return m_clickThrough ? HTTRANSPARENT : HTCAPTION;
    case WM_DESTROY:
      m_hwnd = nullptr;
      return 0;
    default:
      break;
  }
  return DefWindowProcW(m_hwnd, msg, wParam, lParam);
}
