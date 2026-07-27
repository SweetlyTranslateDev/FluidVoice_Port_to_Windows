#pragma once

#include <mutex>
#include <string>

struct whisper_context;
struct SherpaOnnxOfflineRecognizer;

/**
 * Unified speech runtime: Whisper (ggml) or Parakeet TDT (sherpa-onnx).
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

  /** [modelPath] is a ggml file or a Parakeet ONNX model directory. */
  int prepare(const std::string& modelPath);
  /** Returns malloc'd UTF-8 text via outText; caller frees. */
  int transcribe(const float* samples, int sampleCount, int sampleRate,
                 char** outText);

  const char* lastError() const { return m_lastError.c_str(); }

private:
  enum class Backend {
    None,
    Whisper,
    Parakeet,
  };

  void setError(const std::string& msg);
  void freeBackends();
  static bool looksLikeParakeetDir(const std::string& path);
  static bool looksLikeWhisperFile(const std::string& path);
  int prepareWhisper(const std::string& modelPath);
  int prepareParakeet(const std::string& modelDir);
  int transcribeWhisper(const float* samples, int sampleCount, int sampleRate,
                        char** outText);
  int transcribeParakeet(const float* samples, int sampleCount, int sampleRate,
                         char** outText);
  static int threadCount();

  Backend m_backend = Backend::None;
  whisper_context* m_whisper = nullptr;
  const SherpaOnnxOfflineRecognizer* m_parakeet = nullptr;
  std::string m_encoderPath;
  std::string m_decoderPath;
  std::string m_joinerPath;
  std::string m_tokensPath;
  std::string m_loadedPath;
  std::string m_lastError;
  std::mutex m_mutex;
  bool m_initialized = false;
};
