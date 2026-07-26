#pragma once

#include "../../plugin_api/include/fluidvoice_plugin_api.h"

#include <windows.h>

#include <atomic>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

/**
 * Low-level keyboard hook on a dedicated thread with a message pump.
 * Only queues events for the configured shortcut; Dart owns PTT/toggle logic.
 */
class HotkeyHook {
public:
  HotkeyHook();
  ~HotkeyHook();

  HotkeyHook(const HotkeyHook&) = delete;
  HotkeyHook& operator=(const HotkeyHook&) = delete;

  int init();
  void shutdown();

  int setShortcut(int32_t vkCode, int32_t modifiers);
  int start();
  void stop();

  int poll(fv_hotkey_event* out, int32_t maxEvents);

  const char* lastError() const { return m_lastError.c_str(); }

private:
  void hookThreadMain();
  void pushEvent(const fv_hotkey_event& event);
  static LRESULT CALLBACK LowLevelProc(int code, WPARAM wParam, LPARAM lParam);
  static int currentModifiers();

  static HotkeyHook* s_instance;

  std::mutex m_queueMutex;
  std::vector<fv_hotkey_event> m_queue;

  std::thread m_thread;
  std::atomic<bool> m_running{false};
  std::atomic<DWORD> m_threadId{0};
  HHOOK m_hook = nullptr;

  std::atomic<int32_t> m_vk{0};
  std::atomic<int32_t> m_modifiers{0};

  std::string m_lastError;
  bool m_initialized = false;
};
