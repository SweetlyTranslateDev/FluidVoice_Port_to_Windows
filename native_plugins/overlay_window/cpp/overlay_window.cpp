#include "overlay_window.h"

#include <algorithm>
#include <cmath>
#include <cstring>
#include <string>
#include <vector>

namespace {
constexpr wchar_t kClassName[] = L"FluidVoiceOverlayWindow";
constexpr int kPadX = 20;
constexpr int kPadY = 14;
constexpr int kMaxWidth = 720;
constexpr int kMinWidth = 220;
constexpr int kFontPx = 18;

constexpr int kPillW = 176;
constexpr int kPillH = 56;
constexpr int kGap = 16;
constexpr int kTranscriptW = 300;
constexpr int kTranscriptMinH = 72;
constexpr int kTranscriptMaxH = 140;
constexpr int kColorKey = RGB(255, 0, 255);
constexpr UINT_PTR kAnimTimer = 42;

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

void FillRoundRect(HDC hdc, const RECT& rc, int radius, COLORREF fill,
                   COLORREF border, int borderWidth) {
  HBRUSH brush = CreateSolidBrush(fill);
  HPEN pen = CreatePen(PS_SOLID, borderWidth, border);
  HGDIOBJ oldBrush = SelectObject(hdc, brush);
  HGDIOBJ oldPen = SelectObject(hdc, pen);
  RoundRect(hdc, rc.left, rc.top, rc.right, rc.bottom, radius, radius);
  SelectObject(hdc, oldBrush);
  SelectObject(hdc, oldPen);
  DeleteObject(brush);
  DeleteObject(pen);
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
  // Color-key magenta so rounded pill/card float over the desktop.
  SetLayeredWindowAttributes(m_hwnd, kColorKey, 0, LWA_COLORKEY);
  applyClickThrough();
  return true;
}

void OverlayWindow::destroy() {
  killTimer();
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
  ensureTimer();
  ShowWindow(m_hwnd, SW_SHOWNOACTIVATE);
  SetWindowPos(m_hwnd, HWND_TOPMOST, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
}

void OverlayWindow::hide() {
  killTimer();
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

void OverlayWindow::setPillMode(bool enabled) {
  std::lock_guard<std::mutex> lock(m_mutex);
  m_pillMode = enabled;
  if (enabled) {
    // Pill must accept drag; not click-through.
    m_clickThrough = false;
    if (m_hwnd) {
      SetLayeredWindowAttributes(m_hwnd, kColorKey, 0, LWA_COLORKEY);
    }
  } else if (m_hwnd) {
    SetLayeredWindowAttributes(m_hwnd, 0, 230, LWA_ALPHA);
  }
  applyClickThrough();
  if (m_hwnd) {
    layoutToContent();
    ensureTimer();
    InvalidateRect(m_hwnd, nullptr, TRUE);
  }
}

void OverlayWindow::setPhase(const std::string& phase) {
  std::lock_guard<std::mutex> lock(m_mutex);
  if (phase == "listening") {
    m_phase = Phase::Listening;
  } else if (phase == "processing") {
    m_phase = Phase::Processing;
  } else if (phase == "error") {
    m_phase = Phase::Error;
  } else {
    m_phase = Phase::Idle;
    m_amplitude = 0.0;
  }
  if (m_hwnd) {
    ensureTimer();
    InvalidateRect(m_hwnd, nullptr, TRUE);
  }
}

void OverlayWindow::setAmplitude(double amplitude) {
  std::lock_guard<std::mutex> lock(m_mutex);
  m_amplitude = std::clamp(amplitude, 0.0, 1.0);
  if (m_hwnd && m_visible) {
    InvalidateRect(m_hwnd, nullptr, FALSE);
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

void OverlayWindow::ensureTimer() {
  if (!m_hwnd || !m_visible) {
    return;
  }
  const bool needAnim =
      m_pillMode && (m_phase == Phase::Listening || m_phase == Phase::Processing);
  if (needAnim) {
    if (m_timerId == 0) {
      m_timerId = SetTimer(m_hwnd, kAnimTimer, 33, nullptr);
    }
  } else if (m_timerId != 0) {
    KillTimer(m_hwnd, m_timerId);
    m_timerId = 0;
  }
}

void OverlayWindow::killTimer() {
  if (m_hwnd && m_timerId != 0) {
    KillTimer(m_hwnd, m_timerId);
    m_timerId = 0;
  }
}

COLORREF OverlayWindow::phaseColor() const {
  switch (m_phase) {
    case Phase::Listening:
      return RGB(239, 68, 68);
    case Phase::Processing:
      return RGB(245, 158, 11);
    case Phase::Error:
      return RGB(239, 68, 68);
    case Phase::Idle:
    default:
      return RGB(58, 200, 198);
  }
}

const wchar_t* OverlayWindow::phaseLabel() const {
  switch (m_phase) {
    case Phase::Listening:
      return L"Listening";
    case Phase::Processing:
      return L"Working";
    case Phase::Error:
      return L"Error";
    case Phase::Idle:
    default:
      return L"Ready";
  }
}

void OverlayWindow::layoutToContent() {
  if (!m_hwnd) {
    return;
  }

  if (m_pillMode) {
    HDC hdc = GetDC(m_hwnd);
    HFONT font =
        CreateFontW(13, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
                    OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                    DEFAULT_PITCH | FF_SWISS, L"Segoe UI");
    HFONT old = static_cast<HFONT>(SelectObject(hdc, font));
    RECT rc = {0, 0, kTranscriptW - 28, 0};
    std::wstring draw = m_text;
    if (draw.empty()) {
      if (m_phase == Phase::Processing) {
        draw = L"Transcribing…";
      } else if (m_phase == Phase::Listening) {
        draw = L"Listening…";
      } else {
        draw = L"Transcript";
      }
    }
    DrawTextW(hdc, draw.c_str(), static_cast<int>(draw.size()), &rc,
              DT_WORDBREAK | DT_CALCRECT);
    SelectObject(hdc, old);
    DeleteObject(font);
    ReleaseDC(m_hwnd, hdc);
    const int transcriptH =
        std::clamp(static_cast<int>(rc.bottom) + 28, kTranscriptMinH,
                   kTranscriptMaxH);
    // Wide enough to center pill + transcript on the same axis.
    const int width = std::max(kPillW, kTranscriptW) + 24;
    const int height = kPillH + kGap + transcriptH + 8;
    SetWindowPos(m_hwnd, HWND_TOPMOST, m_x, m_y, width, height, SWP_NOACTIVATE);
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
      contentW < kMinWidth ? kMinWidth
                           : (contentW > kMaxWidth ? kMaxWidth : contentW);
  const int height = contentH < 48 ? 48 : contentH;
  SetLayeredWindowAttributes(m_hwnd, 0, 230, LWA_ALPHA);
  SetWindowPos(m_hwnd, HWND_TOPMOST, m_x, m_y, width, height, SWP_NOACTIVATE);
}

void OverlayWindow::paintClassic(HDC hdc, const RECT& client) {
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

void OverlayWindow::paintPillHud(HDC hdc, const RECT& client) {
  // Transparent key background.
  HBRUSH key = CreateSolidBrush(kColorKey);
  FillRect(hdc, &client, key);
  DeleteObject(key);

  const COLORREF accent = phaseColor();
  const int clientW = client.right - client.left;
  const int pillLeft = (clientW - kPillW) / 2;
  const RECT pill = {pillLeft, 0, pillLeft + kPillW, kPillH};

  // Raised flat pill: top highlight → mid → bottom shade.
  FillRoundRect(hdc, pill, kPillH, RGB(36, 36, 38), accent, 2);
  RECT inner = {pillLeft + 2, 2, pillLeft + kPillW - 2, kPillH - 2};
  FillRoundRect(hdc, inner, kPillH - 4, RGB(28, 28, 30), RGB(50, 50, 52), 1);

  // Live waveform bars driven by mic amplitude.
  const int waveLeft = pillLeft + 14;
  const int waveRight = pillLeft + kPillW - 70;
  const int waveMidY = kPillH / 2;
  const int bars = 18;
  const int gap = 2;
  const int barW =
      std::max(2, (waveRight - waveLeft - (bars - 1) * gap) / bars);
  const double base =
      (m_phase == Phase::Listening)
          ? std::max(0.12, m_amplitude)
          : (m_phase == Phase::Processing ? 0.35 : 0.08);

  for (int i = 0; i < bars; ++i) {
    const double t = m_wavePhase + i * 0.55;
    const double wobble =
        0.55 + 0.45 * std::sin(t) * std::sin(t * 0.37 + i * 0.2);
    const double hNorm = std::clamp(base * wobble, 0.06, 1.0);
    const int h = static_cast<int>((kPillH - 18) * hNorm);
    const int x = waveLeft + i * (barW + gap);
    const int y0 = waveMidY - h / 2;
    const int y1 = y0 + h;
    RECT bar = {x, y0, x + barW, y1};
    HBRUSH b = CreateSolidBrush(accent);
    FillRect(hdc, &bar, b);
    DeleteObject(b);
  }

  HFONT labelFont =
      CreateFontW(11, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
                  OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                  DEFAULT_PITCH | FF_SWISS, L"Segoe UI");
  HFONT old = static_cast<HFONT>(SelectObject(hdc, labelFont));
  SetBkMode(hdc, TRANSPARENT);
  SetTextColor(hdc, RGB(242, 242, 242));
  RECT labelRc = {pillLeft + kPillW - 66, 0, pillLeft + kPillW - 8, kPillH};
  DrawTextW(hdc, phaseLabel(), -1, &labelRc,
            DT_SINGLELINE | DT_VCENTER | DT_RIGHT);
  SelectObject(hdc, old);
  DeleteObject(labelFont);

  // Transcript card centered under the pill.
  const int top = kPillH + kGap;
  const int cardLeft = (clientW - kTranscriptW) / 2;
  RECT card = {cardLeft, top, cardLeft + kTranscriptW, client.bottom - 4};
  if (card.bottom < card.top + kTranscriptMinH) {
    card.bottom = card.top + kTranscriptMinH;
  }
  FillRoundRect(hdc, card, 16, RGB(28, 28, 30),
                RGB(GetRValue(accent) / 2 + 40, GetGValue(accent) / 2 + 40,
                    GetBValue(accent) / 2 + 40),
                1);

  HFONT bodyFont =
      CreateFontW(13, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
                  OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                  DEFAULT_PITCH | FF_SWISS, L"Segoe UI");
  old = static_cast<HFONT>(SelectObject(hdc, bodyFont));
  SetTextColor(hdc, m_text.empty() ? RGB(115, 115, 115) : RGB(242, 242, 242));
  RECT textRc = card;
  textRc.left += 14;
  textRc.right -= 14;
  textRc.top += 12;
  textRc.bottom -= 12;
  std::wstring draw = m_text;
  if (draw.empty()) {
    if (m_phase == Phase::Processing) {
      draw = L"Transcribing…";
      SetTextColor(hdc, RGB(242, 242, 242));
    } else if (m_phase == Phase::Listening) {
      draw = L"Listening…";
      SetTextColor(hdc, RGB(242, 242, 242));
    } else if (m_phase == Phase::Error) {
      draw = L"Error";
      SetTextColor(hdc, RGB(239, 68, 68));
    } else {
      draw = L"Transcript";
    }
  }
  DrawTextW(hdc, draw.c_str(), static_cast<int>(draw.size()), &textRc,
            DT_WORDBREAK | DT_CENTER | DT_TOP | DT_END_ELLIPSIS);
  SelectObject(hdc, old);
  DeleteObject(bodyFont);
}

void OverlayWindow::paint(HDC hdc) {
  RECT client{};
  GetClientRect(m_hwnd, &client);
  if (m_pillMode) {
    // Ensure color-key transparency for pill HUD.
    SetLayeredWindowAttributes(m_hwnd, kColorKey, 0, LWA_COLORKEY);
    paintPillHud(hdc, client);
  } else {
    paintClassic(hdc, client);
  }
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
    case WM_TIMER:
      if (wParam == kAnimTimer) {
        m_wavePhase += 0.35;
        InvalidateRect(m_hwnd, nullptr, FALSE);
      }
      return 0;
    case WM_ERASEBKGND:
      return 1;
    case WM_NCHITTEST:
      // Pill mode: drag the whole HUD like a caption.
      if (m_pillMode && !m_clickThrough) {
        return HTCAPTION;
      }
      return m_clickThrough ? HTTRANSPARENT : HTCAPTION;
    case WM_DESTROY:
      if (m_timerId != 0) {
        KillTimer(m_hwnd, m_timerId);
        m_timerId = 0;
      }
      m_hwnd = nullptr;
      return 0;
    default:
      break;
  }
  return DefWindowProcW(m_hwnd, msg, wParam, lParam);
}
