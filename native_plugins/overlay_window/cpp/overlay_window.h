#pragma once

#include <windows.h>

#include <mutex>
#include <string>

/**
 * Frameless always-on-top overlay (no Flutter engine).
 *
 * Two modes:
 * - Classic transcript chip (during dictation when floating pill is off)
 * - Persistent pill HUD: separate always-on-top window with wave pill +
 *   transcript card; survives main-window minimize/hide
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

  /** Persistent floating pill HUD (independent of the main Flutter window). */
  void setPillMode(bool enabled);
  void setPhase(const std::string& phase);
  void setAmplitude(double amplitude);

  static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam,
                                  LPARAM lParam);

private:
  enum class Phase {
    Idle,
    Listening,
    Processing,
    Error,
  };

  LRESULT handleMessage(UINT msg, WPARAM wParam, LPARAM lParam);
  void paint(HDC hdc);
  void paintClassic(HDC hdc, const RECT& client);
  void paintPillHud(HDC hdc, const RECT& client);
  void applyClickThrough();
  void layoutToContent();
  void ensureTimer();
  void killTimer();
  COLORREF phaseColor() const;
  const wchar_t* phaseLabel() const;

  HWND m_hwnd = nullptr;
  std::wstring m_text;
  bool m_clickThrough = true;
  bool m_visible = false;
  bool m_pillMode = false;
  Phase m_phase = Phase::Idle;
  double m_amplitude = 0.0;
  double m_wavePhase = 0.0;
  UINT_PTR m_timerId = 0;
  int m_x = 40;
  int m_y = 40;
  std::mutex m_mutex;
};
