#include "speech_engine.h"

#include "whisper.h"

#include <cstdlib>
#include <cstring>
#include <vector>

SpeechEngine::SpeechEngine() = default;

SpeechEngine::~SpeechEngine() { shutdown(); }

void SpeechEngine::setError(const std::string& msg) { m_lastError = msg; }

void SpeechEngine::freeContext() {
  if (m_ctx) {
    whisper_free(m_ctx);
    m_ctx = nullptr;
  }
  m_loadedPath.clear();
}

int SpeechEngine::init() {
  std::lock_guard<std::mutex> lock(m_mutex);
  m_initialized = true;
  m_lastError.clear();
  return 0;
}

void SpeechEngine::shutdown() {
  std::lock_guard<std::mutex> lock(m_mutex);
  freeContext();
  m_initialized = false;
}

int SpeechEngine::prepare(const std::string& modelPath) {
  std::lock_guard<std::mutex> lock(m_mutex);
  if (!m_initialized) {
    setError("Speech engine not initialized");
    return -1;
  }
  if (modelPath.empty()) {
    setError("Model path is empty");
    return -1;
  }
  if (m_ctx && m_loadedPath == modelPath) {
    return 0;
  }

  freeContext();

  whisper_context_params cparams = whisper_context_default_params();
  m_ctx = whisper_init_from_file_with_params(modelPath.c_str(), cparams);
  if (!m_ctx) {
    setError("Failed to load Whisper model: " + modelPath);
    return -1;
  }

  m_loadedPath = modelPath;
  m_lastError.clear();
  return 0;
}

int SpeechEngine::transcribe(const float* samples, int sampleCount,
                             int sampleRate, char** outText) {
  if (!outText) {
    return -1;
  }
  *outText = nullptr;

  std::lock_guard<std::mutex> lock(m_mutex);
  if (!m_ctx) {
    setError("No model loaded; call fv_speech_prepare first");
    return -1;
  }
  if (!samples || sampleCount <= 0) {
    setError("No audio samples");
    return -1;
  }
  if (sampleRate != WHISPER_SAMPLE_RATE) {
    setError("Sample rate must be 16000 Hz");
    return -1;
  }

  whisper_full_params wparams =
      whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
  wparams.print_progress = false;
  wparams.print_special = false;
  wparams.print_realtime = false;
  wparams.print_timestamps = false;
  wparams.translate = false;
  wparams.language = "en";
  wparams.n_threads = 4;
  wparams.no_context = true;
  wparams.single_segment = false;

  const int rc = whisper_full(m_ctx, wparams, samples, sampleCount);
  if (rc != 0) {
    setError("whisper_full failed");
    return -1;
  }

  std::string text;
  const int nSegments = whisper_full_n_segments(m_ctx);
  for (int i = 0; i < nSegments; ++i) {
    const char* seg = whisper_full_get_segment_text(m_ctx, i);
    if (seg) {
      text += seg;
    }
  }

  // Trim leading whitespace Whisper often prepends.
  while (!text.empty() &&
         (text.front() == ' ' || text.front() == '\n' || text.front() == '\t')) {
    text.erase(text.begin());
  }

  char* copy = static_cast<char*>(std::malloc(text.size() + 1));
  if (!copy) {
    setError("Out of memory");
    return -1;
  }
  std::memcpy(copy, text.c_str(), text.size() + 1);
  *outText = copy;
  m_lastError.clear();
  return 0;
}
