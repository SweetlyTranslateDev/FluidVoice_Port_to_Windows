#include "text_injector.h"

#include <windows.h>
#include <UIAutomation.h>

#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

namespace {

std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) {
    return L"";
  }
  const int n = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(),
                                    static_cast<int>(utf8.size()), nullptr, 0);
  if (n <= 0) {
    return L"";
  }
  std::wstring out(static_cast<size_t>(n), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), static_cast<int>(utf8.size()),
                      out.data(), n);
  return out;
}

std::string WideToUtf8(const std::wstring& wide) {
  if (wide.empty()) {
    return "";
  }
  const int n = WideCharToMultiByte(CP_UTF8, 0, wide.c_str(),
                                    static_cast<int>(wide.size()), nullptr, 0,
                                    nullptr, nullptr);
  if (n <= 0) {
    return "";
  }
  std::string out(static_cast<size_t>(n), '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), static_cast<int>(wide.size()),
                      out.data(), n, nullptr, nullptr);
  return out;
}

class ComScope {
public:
  ComScope() {
    const HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    m_ok = SUCCEEDED(hr) || hr == RPC_E_CHANGED_MODE;
    m_needUninit = hr == S_OK;
  }
  ~ComScope() {
    if (m_needUninit) {
      CoUninitialize();
    }
  }
  bool ok() const { return m_ok; }

private:
  bool m_ok = false;
  bool m_needUninit = false;
};

bool SendCtrlKey(WORD vk) {
  INPUT keys[4] = {};
  keys[0].type = INPUT_KEYBOARD;
  keys[0].ki.wVk = VK_CONTROL;
  keys[1].type = INPUT_KEYBOARD;
  keys[1].ki.wVk = vk;
  keys[2].type = INPUT_KEYBOARD;
  keys[2].ki.wVk = vk;
  keys[2].ki.dwFlags = KEYEVENTF_KEYUP;
  keys[3].type = INPUT_KEYBOARD;
  keys[3].ki.wVk = VK_CONTROL;
  keys[3].ki.dwFlags = KEYEVENTF_KEYUP;
  return SendInput(4, keys, sizeof(INPUT)) == 4;
}

bool GetClipboardUnicode(std::wstring* out) {
  out->clear();
  if (!OpenClipboard(nullptr)) {
    return false;
  }
  HANDLE data = GetClipboardData(CF_UNICODETEXT);
  if (data) {
    const wchar_t* text = static_cast<const wchar_t*>(GlobalLock(data));
    if (text) {
      *out = text;
      GlobalUnlock(data);
    }
  }
  CloseClipboard();
  return true;
}

bool SetClipboardUnicode(const std::wstring& text) {
  if (!OpenClipboard(nullptr)) {
    return false;
  }
  EmptyClipboard();
  const size_t bytes = (text.size() + 1) * sizeof(wchar_t);
  HGLOBAL mem = GlobalAlloc(GMEM_MOVEABLE, bytes);
  if (!mem) {
    CloseClipboard();
    return false;
  }
  void* locked = GlobalLock(mem);
  if (!locked) {
    GlobalFree(mem);
    CloseClipboard();
    return false;
  }
  std::memcpy(locked, text.c_str(), bytes);
  GlobalUnlock(mem);
  if (!SetClipboardData(CF_UNICODETEXT, mem)) {
    GlobalFree(mem);
    CloseClipboard();
    return false;
  }
  CloseClipboard();
  return true;
}

bool PostCharsToHwnd(HWND hwnd, const std::wstring& text) {
  if (!hwnd || !IsWindow(hwnd) || text.empty()) {
    return false;
  }
  for (const wchar_t ch : text) {
    if (ch == L'\n') {
      PostMessageW(hwnd, WM_CHAR, VK_RETURN, 0);
    } else if (ch == L'\r') {
      continue;
    } else {
      PostMessageW(hwnd, WM_CHAR, static_cast<WPARAM>(ch), 0);
    }
  }
  return true;
}

HWND FocusedHwndViaUia() {
  ComScope com;
  if (!com.ok()) {
    return nullptr;
  }

  IUIAutomation* automation = nullptr;
  HRESULT hr =
      CoCreateInstance(CLSID_CUIAutomation, nullptr, CLSCTX_INPROC_SERVER,
                       IID_IUIAutomation, reinterpret_cast<void**>(&automation));
  if (FAILED(hr) || !automation) {
    return nullptr;
  }

  IUIAutomationElement* focused = nullptr;
  hr = automation->GetFocusedElement(&focused);
  HWND hwnd = nullptr;
  if (SUCCEEDED(hr) && focused) {
    UIA_HWND uiaHwnd = nullptr;
    if (SUCCEEDED(focused->get_CurrentNativeWindowHandle(&uiaHwnd)) &&
        uiaHwnd) {
      hwnd = static_cast<HWND>(uiaHwnd);
    }
    focused->Release();
  }
  automation->Release();
  return hwnd;
}

HWND FocusedHwndViaGuiThread() {
  GUITHREADINFO info = {};
  info.cbSize = sizeof(info);
  if (!GetGUIThreadInfo(0, &info)) {
    return nullptr;
  }
  if (info.hwndFocus) {
    return info.hwndFocus;
  }
  return info.hwndCaret;
}

}  // namespace

void TextInjector::setError(const std::string& msg) { m_lastError = msg; }

bool TextInjector::tryInsertViaUia(const std::wstring& text) {
  // UIA resolves the focused native HWND; characters are posted as WM_CHAR.
  HWND hwnd = FocusedHwndViaUia();
  if (!hwnd) {
    hwnd = FocusedHwndViaGuiThread();
  }
  return PostCharsToHwnd(hwnd, text);
}

bool TextInjector::tryInsertViaSendInput(const std::wstring& text) {
  if (text.empty() || text.size() > 4000) {
    return false;
  }

  std::vector<INPUT> inputs;
  inputs.reserve(text.size() * 2);
  for (const wchar_t ch : text) {
    INPUT down = {};
    down.type = INPUT_KEYBOARD;
    down.ki.wScan = ch;
    down.ki.dwFlags = KEYEVENTF_UNICODE;
    INPUT up = down;
    up.ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;
    inputs.push_back(down);
    inputs.push_back(up);
  }

  const UINT sent =
      SendInput(static_cast<UINT>(inputs.size()), inputs.data(), sizeof(INPUT));
  return sent == inputs.size();
}

bool TextInjector::tryInsertViaClipboard(const std::wstring& text) {
  std::wstring previous;
  const bool hadPrevious = GetClipboardUnicode(&previous);

  if (!SetClipboardUnicode(text)) {
    return false;
  }

  Sleep(30);
  const bool pasted = SendCtrlKey('V');
  Sleep(40);

  if (hadPrevious) {
    SetClipboardUnicode(previous);
  } else if (OpenClipboard(nullptr)) {
    EmptyClipboard();
    CloseClipboard();
  }

  return pasted;
}

bool TextInjector::tryReadViaUia(std::wstring* out) {
  out->clear();
  ComScope com;
  if (!com.ok()) {
    return false;
  }

  IUIAutomation* automation = nullptr;
  HRESULT hr =
      CoCreateInstance(CLSID_CUIAutomation, nullptr, CLSCTX_INPROC_SERVER,
                       IID_IUIAutomation, reinterpret_cast<void**>(&automation));
  if (FAILED(hr) || !automation) {
    return false;
  }

  IUIAutomationElement* focused = nullptr;
  hr = automation->GetFocusedElement(&focused);
  if (FAILED(hr) || !focused) {
    automation->Release();
    return false;
  }

  bool ok = false;
  IUnknown* patternUnk = nullptr;
  hr = focused->GetCurrentPattern(UIA_TextPatternId, &patternUnk);
  if (SUCCEEDED(hr) && patternUnk) {
    IUIAutomationTextPattern* textPattern = nullptr;
    hr = patternUnk->QueryInterface(IID_IUIAutomationTextPattern,
                                    reinterpret_cast<void**>(&textPattern));
    patternUnk->Release();
    if (SUCCEEDED(hr) && textPattern) {
      IUIAutomationTextRangeArray* ranges = nullptr;
      hr = textPattern->GetSelection(&ranges);
      if (SUCCEEDED(hr) && ranges) {
        int length = 0;
        ranges->get_Length(&length);
        if (length > 0) {
          IUIAutomationTextRange* range = nullptr;
          if (SUCCEEDED(ranges->GetElement(0, &range)) && range) {
            BSTR bstr = nullptr;
            if (SUCCEEDED(range->GetText(-1, &bstr)) && bstr) {
              *out = bstr;
              SysFreeString(bstr);
              ok = true;
            }
            range->Release();
          }
        }
        ranges->Release();
      }
      textPattern->Release();
    }
  }

  focused->Release();
  automation->Release();
  return ok;
}

bool TextInjector::tryReadViaClipboardCopy(std::wstring* out) {
  out->clear();
  std::wstring previous;
  const bool hadPrevious = GetClipboardUnicode(&previous);

  if (!SendCtrlKey('C')) {
    return false;
  }
  Sleep(50);

  std::wstring copied;
  if (!GetClipboardUnicode(&copied)) {
    return false;
  }

  if (hadPrevious) {
    SetClipboardUnicode(previous);
  } else if (OpenClipboard(nullptr)) {
    EmptyClipboard();
    CloseClipboard();
  }

  if (hadPrevious && copied == previous) {
    return false;
  }

  *out = copied;
  return true;
}

int TextInjector::insertText(const std::string& utf8) {
  if (utf8.empty()) {
    m_lastError.clear();
    return 0;
  }

  const std::wstring text = Utf8ToWide(utf8);
  if (text.empty()) {
    setError("Failed to convert text to UTF-16");
    return -1;
  }

  // SendInput / clipboard are more reliable than WM_CHAR alone; UIA path posts
  // WM_CHAR to the focused HWND as a last resort (cannot verify insertion).
  if (tryInsertViaSendInput(text)) {
    m_lastError.clear();
    return 0;
  }
  if (tryInsertViaClipboard(text)) {
    m_lastError.clear();
    return 0;
  }
  if (tryInsertViaUia(text)) {
    m_lastError.clear();
    return 0;
  }

  setError("All text injection strategies failed (SendInput, clipboard, UIA)");
  return -1;
}

int TextInjector::readSelection(char** outText) {
  if (!outText) {
    return -1;
  }
  *outText = nullptr;

  std::wstring selected;
  if (!tryReadViaUia(&selected)) {
    if (!tryReadViaClipboardCopy(&selected)) {
      setError("Could not read selection via UIA or clipboard");
      return -1;
    }
  }

  const std::string utf8 = WideToUtf8(selected);
  char* copy = static_cast<char*>(std::malloc(utf8.size() + 1));
  if (!copy) {
    setError("Out of memory");
    return -1;
  }
  std::memcpy(copy, utf8.c_str(), utf8.size() + 1);
  *outText = copy;
  m_lastError.clear();
  return 0;
}
