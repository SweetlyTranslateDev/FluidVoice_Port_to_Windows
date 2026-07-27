#include "hotkey_hook.h"

#include <algorithm>
#include <cstdio>

namespace {
constexpr size_t kMaxQueue = 256;
constexpr UINT kMsgStop = WM_APP + 42;
}  // namespace

HotkeyHook* HotkeyHook::s_instance = nullptr;

HotkeyHook::HotkeyHook() = default;

HotkeyHook::~HotkeyHook() { shutdown(); }

int HotkeyHook::init() {
  if (m_initialized) {
    return 0;
  }
  s_instance = this;
  m_initialized = true;
  m_lastError.clear();
  return 0;
}

void HotkeyHook::shutdown() {
  stop();
  if (s_instance == this) {
    s_instance = nullptr;
  }
  m_initialized = false;
}

int HotkeyHook::setShortcut(int32_t vkCode, int32_t modifiers) {
  if (vkCode <= 0) {
    m_lastError = "Invalid virtual-key code";
    return -1;
  }
  m_vk.store(vkCode);
  m_modifiers.store(modifiers);
  return 0;
}

int HotkeyHook::start() {
  if (!m_initialized) {
    m_lastError = "Hotkey hook not initialized";
    return -1;
  }
  if (m_vk.load() == 0) {
    m_lastError = "Shortcut not configured";
    return -1;
  }
  if (m_running.load()) {
    return 0;
  }

  {
    std::lock_guard<std::mutex> lock(m_queueMutex);
    m_queue.clear();
  }

  m_running.store(true);
  m_armed.store(false);
  m_thread = std::thread(&HotkeyHook::hookThreadMain, this);

  // Wait briefly for the hook thread to install.
  for (int i = 0; i < 50 && m_threadId.load() == 0; ++i) {
    Sleep(10);
  }
  if (m_threadId.load() == 0) {
    m_lastError = "Hotkey thread failed to start";
    stop();
    return -1;
  }
  m_lastError.clear();
  return 0;
}

void HotkeyHook::stop() {
  if (!m_running.load() && !m_thread.joinable()) {
    return;
  }
  m_running.store(false);
  const DWORD tid = m_threadId.load();
  if (tid != 0) {
    PostThreadMessageW(tid, kMsgStop, 0, 0);
  }
  if (m_thread.joinable()) {
    m_thread.join();
  }
  m_threadId.store(0);
}

int HotkeyHook::poll(fv_hotkey_event* out, int32_t maxEvents) {
  if (!out || maxEvents <= 0) {
    return 0;
  }
  std::lock_guard<std::mutex> lock(m_queueMutex);
  const size_t n =
      (m_queue.size() < static_cast<size_t>(maxEvents))
          ? m_queue.size()
          : static_cast<size_t>(maxEvents);
  for (size_t i = 0; i < n; ++i) {
    out[i] = m_queue[i];
  }
  if (n > 0) {
    m_queue.erase(m_queue.begin(),
                  m_queue.begin() + static_cast<std::ptrdiff_t>(n));
  }
  return static_cast<int>(n);
}

void HotkeyHook::pushEvent(const fv_hotkey_event& event) {
  std::lock_guard<std::mutex> lock(m_queueMutex);
  if (m_queue.size() >= kMaxQueue) {
    m_queue.erase(m_queue.begin());
  }
  m_queue.push_back(event);
}

int HotkeyHook::currentModifiers() {
  int mods = 0;
  if ((GetAsyncKeyState(VK_CONTROL) & 0x8000) != 0) {
    mods |= FV_HOTKEY_MOD_CONTROL;
  }
  if ((GetAsyncKeyState(VK_MENU) & 0x8000) != 0) {
    mods |= FV_HOTKEY_MOD_ALT;
  }
  if ((GetAsyncKeyState(VK_SHIFT) & 0x8000) != 0) {
    mods |= FV_HOTKEY_MOD_SHIFT;
  }
  if ((GetAsyncKeyState(VK_LWIN) & 0x8000) != 0 ||
      (GetAsyncKeyState(VK_RWIN) & 0x8000) != 0) {
    mods |= FV_HOTKEY_MOD_WIN;
  }
  return mods;
}

LRESULT CALLBACK HotkeyHook::LowLevelProc(int code, WPARAM wParam,
                                          LPARAM lParam) {
  if (code == HC_ACTION && s_instance) {
    const auto* info = reinterpret_cast<KBDLLHOOKSTRUCT*>(lParam);
    // Injected events (e.g. our own text insert) must pass through.
    if ((info->flags & LLKHF_INJECTED) == 0) {
      const int32_t vk = static_cast<int32_t>(info->vkCode);
      const int32_t wantVk = s_instance->m_vk.load();
      const int32_t wantMods = s_instance->m_modifiers.load();

      if (vk == wantVk && wantVk != 0) {
        const bool isUp =
            (wParam == WM_KEYUP || wParam == WM_SYSKEYUP);
        const bool isDown =
            (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN);

        if (isDown || isUp) {
          const int mods = currentModifiers();
          const bool modsOk = (mods & wantMods) == wantMods;
          bool swallow = false;

          if (isDown) {
            if (modsOk) {
              // Arm on first matching down; swallow all repeats too.
              const bool alreadyArmed = s_instance->m_armed.load();
              s_instance->m_armed.store(true);
              if (!alreadyArmed) {
                fv_hotkey_event event{};
                event.type = FV_HOTKEY_EVENT_DOWN;
                event.vk_code = vk;
                event.modifiers = mods;
                s_instance->pushEvent(event);
              }
              swallow = true;
            } else if (s_instance->m_armed.load()) {
              // Still holding trigger after a matching chord — block typing.
              swallow = true;
            }
          } else if (isUp) {
            if (s_instance->m_armed.load() || modsOk) {
              fv_hotkey_event event{};
              event.type = FV_HOTKEY_EVENT_UP;
              event.vk_code = vk;
              event.modifiers = mods;
              s_instance->pushEvent(event);
              s_instance->m_armed.store(false);
              swallow = true;
            }
          }

          if (swallow) {
            // Block the key from reaching other apps (fixes Space insertion).
            return 1;
          }
        }
      }
    }
  }
  return CallNextHookEx(nullptr, code, wParam, lParam);
}

void HotkeyHook::hookThreadMain() {
  // WH_KEYBOARD_LL requires a message loop on the installing thread.
  m_threadId.store(GetCurrentThreadId());

  // Force creation of a message queue before installing the hook.
  MSG msg;
  PeekMessageW(&msg, nullptr, WM_USER, WM_USER, PM_NOREMOVE);

  m_hook = SetWindowsHookExW(WH_KEYBOARD_LL, LowLevelProc, GetModuleHandleW(nullptr), 0);
  if (!m_hook) {
    m_lastError = "SetWindowsHookExW(WH_KEYBOARD_LL) failed";
    m_running.store(false);
    m_threadId.store(0);
    return;
  }

  while (m_running.load()) {
    const BOOL ok = GetMessageW(&msg, nullptr, 0, 0);
    if (ok <= 0) {
      break;
    }
    if (msg.message == kMsgStop) {
      break;
    }
    TranslateMessage(&msg);
    DispatchMessageW(&msg);
  }

  if (m_hook) {
    UnhookWindowsHookEx(m_hook);
    m_hook = nullptr;
  }
  m_threadId.store(0);
  m_running.store(false);
}
