#pragma once

#include <string>

/**
 * Focused-app text insert / selection read.
 * Strategy: UI Automation → SendInput Unicode → clipboard paste+restore.
 * No dictation business logic.
 */
class TextInjector {
public:
  int insertText(const std::string& utf8);
  int readSelection(char** outText);

  const char* lastError() const { return m_lastError.c_str(); }

private:
  void setError(const std::string& msg);

  bool tryInsertViaUia(const std::wstring& text);
  bool tryInsertViaSendInput(const std::wstring& text);
  bool tryInsertViaClipboard(const std::wstring& text);

  bool tryReadViaUia(std::wstring* out);
  bool tryReadViaClipboardCopy(std::wstring* out);

  std::string m_lastError;
};
