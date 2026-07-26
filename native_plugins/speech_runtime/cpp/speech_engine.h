#pragma once

#include <mutex>
#include <string>

struct whisper_context;

/**
 * Unified speech runtime backend (whisper.cpp for Phase 1).
 * No dictation business logic — load model + transcribe PCM only.
 */
class SpeechEngine {
public:
  SpeechEngine();
  ~SpeechEngine();

  SpeechEngine(const SpeechEngine&) = delete;
  SpeechEngine& operator=(const SpeechEngine&) = delete;

  int init();
  void shutdown();

  int prepare(const std::string& modelPath);
  /** Returns malloc'd UTF-8 text via outText; caller frees. */
  int transcribe(const float* samples, int sampleCount, int sampleRate,
                 char** outText);

  const char* lastError() const { return m_lastError.c_str(); }

private:
  void setError(const std::string& msg);
  void freeContext();

  whisper_context* m_ctx = nullptr;
  std::string m_loadedPath;
  std::string m_lastError;
  std::mutex m_mutex;
  bool m_initialized = false;
};
