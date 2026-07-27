#include "speech_engine.h"

#include "whisper.h"

#include "sherpa-onnx/c-api/c-api.h"

#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <thread>
#include <vector>

namespace fs = std::filesystem;

namespace {

std::string findFileByPrefix(const fs::path& dir, const char* prefix,
                             const char* suffix) {
  if (!fs::exists(dir) || !fs::is_directory(dir)) {
    return {};
  }
  for (const auto& entry : fs::directory_iterator(dir)) {
    if (!entry.is_regular_file()) {
      continue;
    }
    const auto name = entry.path().filename().string();
    if (name.rfind(prefix, 0) == 0 &&
        name.size() >= std::strlen(suffix) &&
        name.compare(name.size() - std::strlen(suffix), std::strlen(suffix),
                     suffix) == 0) {
      return entry.path().string();
    }
  }
  return {};
}

char* dupCString(const std::string& text) {
  char* copy = static_cast<char*>(std::malloc(text.size() + 1));
  if (!copy) {
    return nullptr;
  }
  std::memcpy(copy, text.c_str(), text.size() + 1);
  return copy;
}

}  // namespace

SpeechEngine::SpeechEngine() = default;

SpeechEngine::~SpeechEngine() { shutdown(); }

void SpeechEngine::setError(const std::string& msg) { m_lastError = msg; }

int SpeechEngine::threadCount() {
  const unsigned n = std::thread::hardware_concurrency();
  return static_cast<int>(n == 0 ? 4 : n);
}

void SpeechEngine::freeBackends() {
  if (m_whisper) {
    whisper_free(m_whisper);
    m_whisper = nullptr;
  }
  if (m_parakeet) {
    SherpaOnnxDestroyOfflineRecognizer(m_parakeet);
    m_parakeet = nullptr;
  }
  m_backend = Backend::None;
  m_whisperMultilingual = false;
  m_encoderPath.clear();
  m_decoderPath.clear();
  m_joinerPath.clear();
  m_tokensPath.clear();
  m_loadedPath.clear();
}

bool SpeechEngine::looksLikeWhisperFile(const std::string& path) {
  std::error_code ec;
  if (!fs::is_regular_file(path, ec)) {
    return false;
  }
  const auto ext = fs::path(path).extension().string();
  return ext == ".bin" || ext == ".gguf" || ext == ".ggml";
}

bool SpeechEngine::looksLikeParakeetDir(const std::string& path) {
  std::error_code ec;
  if (!fs::is_directory(path, ec)) {
    return false;
  }
  const fs::path dir(path);
  const bool hasTokens = fs::exists(dir / "tokens.txt", ec);
  const bool hasEncoder =
      !findFileByPrefix(dir, "encoder", ".onnx").empty();
  const bool hasDecoder =
      !findFileByPrefix(dir, "decoder", ".onnx").empty();
  const bool hasJoiner = !findFileByPrefix(dir, "joiner", ".onnx").empty();
  return hasTokens && hasEncoder && hasDecoder && hasJoiner;
}

int SpeechEngine::init() {
  std::lock_guard<std::mutex> lock(m_mutex);
  m_initialized = true;
  m_lastError.clear();
  return 0;
}

void SpeechEngine::shutdown() {
  std::lock_guard<std::mutex> lock(m_mutex);
  freeBackends();
  m_initialized = false;
}

int SpeechEngine::prepareWhisper(const std::string& modelPath) {
  whisper_context_params cparams = whisper_context_default_params();
  m_whisper = whisper_init_from_file_with_params(modelPath.c_str(), cparams);
  if (!m_whisper) {
    setError("Failed to load Whisper model: " + modelPath);
    return -1;
  }
  m_whisperMultilingual = whisper_is_multilingual(m_whisper) != 0;
  m_backend = Backend::Whisper;
  m_loadedPath = modelPath;
  m_lastError.clear();
  return 0;
}

int SpeechEngine::prepareParakeet(const std::string& modelDir) {
  const fs::path dir(modelDir);
  m_encoderPath = findFileByPrefix(dir, "encoder", ".onnx");
  m_decoderPath = findFileByPrefix(dir, "decoder", ".onnx");
  m_joinerPath = findFileByPrefix(dir, "joiner", ".onnx");
  m_tokensPath = (dir / "tokens.txt").string();

  if (m_encoderPath.empty() || m_decoderPath.empty() || m_joinerPath.empty() ||
      !fs::exists(m_tokensPath)) {
    setError("Parakeet model directory incomplete: " + modelDir);
    return -1;
  }

  SherpaOnnxOfflineRecognizerConfig config;
  std::memset(&config, 0, sizeof(config));
  config.feat_config.sample_rate = 16000;
  config.feat_config.feature_dim = 80;
  config.model_config.transducer.encoder = m_encoderPath.c_str();
  config.model_config.transducer.decoder = m_decoderPath.c_str();
  config.model_config.transducer.joiner = m_joinerPath.c_str();
  config.model_config.tokens = m_tokensPath.c_str();
  config.model_config.num_threads = threadCount();
  config.model_config.provider = "cpu";
  config.model_config.model_type = "nemo_transducer";
  config.model_config.debug = 0;
  config.decoding_method = "greedy_search";

  m_parakeet = SherpaOnnxCreateOfflineRecognizer(&config);
  if (!m_parakeet) {
    setError("Failed to create Parakeet/sherpa-onnx recognizer for: " +
             modelDir);
    return -1;
  }

  m_backend = Backend::Parakeet;
  m_loadedPath = modelDir;
  m_lastError.clear();
  return 0;
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
  if (m_backend != Backend::None && m_loadedPath == modelPath) {
    return 0;
  }

  freeBackends();

  if (looksLikeParakeetDir(modelPath)) {
    return prepareParakeet(modelPath);
  }
  if (looksLikeWhisperFile(modelPath)) {
    return prepareWhisper(modelPath);
  }

  setError(
      "Unrecognized model path (need ggml .bin or Parakeet ONNX directory): " +
      modelPath);
  return -1;
}

int SpeechEngine::transcribeWhisper(const float* samples, int sampleCount,
                                    int sampleRate, char** outText) {
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
  // English-only ggml models require "en"; multilingual uses auto-detect.
  if (m_whisperMultilingual) {
    wparams.language = "auto";
    wparams.detect_language = true;
  } else {
    wparams.language = "en";
    wparams.detect_language = false;
  }
  wparams.n_threads = threadCount();
  wparams.no_context = true;
  wparams.single_segment = false;

  const int rc = whisper_full(m_whisper, wparams, samples, sampleCount);
  if (rc != 0) {
    setError("whisper_full failed");
    return -1;
  }

  std::string text;
  const int nSegments = whisper_full_n_segments(m_whisper);
  for (int i = 0; i < nSegments; ++i) {
    const char* seg = whisper_full_get_segment_text(m_whisper, i);
    if (seg) {
      text += seg;
    }
  }

  while (!text.empty() &&
         (text.front() == ' ' || text.front() == '\n' || text.front() == '\t')) {
    text.erase(text.begin());
  }

  *outText = dupCString(text);
  if (!*outText) {
    setError("Out of memory");
    return -1;
  }
  m_lastError.clear();
  return 0;
}

int SpeechEngine::transcribeParakeet(const float* samples, int sampleCount,
                                     int sampleRate, char** outText) {
  if (sampleRate <= 0) {
    setError("Invalid sample rate");
    return -1;
  }

  const SherpaOnnxOfflineStream* stream =
      SherpaOnnxCreateOfflineStream(m_parakeet);
  if (!stream) {
    setError("Failed to create Parakeet stream");
    return -1;
  }

  SherpaOnnxAcceptWaveformOffline(stream, sampleRate, samples, sampleCount);
  SherpaOnnxDecodeOfflineStream(m_parakeet, stream);
  const SherpaOnnxOfflineRecognizerResult* result =
      SherpaOnnxGetOfflineStreamResult(stream);

  std::string text;
  if (result && result->text) {
    text = result->text;
  }
  if (result) {
    SherpaOnnxDestroyOfflineRecognizerResult(result);
  }
  SherpaOnnxDestroyOfflineStream(stream);

  while (!text.empty() &&
         (text.front() == ' ' || text.front() == '\n' || text.front() == '\t')) {
    text.erase(text.begin());
  }

  *outText = dupCString(text);
  if (!*outText) {
    setError("Out of memory");
    return -1;
  }
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
  if (m_backend == Backend::None) {
    setError("No model loaded; call fv_speech_prepare first");
    return -1;
  }
  if (!samples || sampleCount <= 0) {
    setError("No audio samples");
    return -1;
  }

  switch (m_backend) {
    case Backend::Whisper:
      return transcribeWhisper(samples, sampleCount, sampleRate, outText);
    case Backend::Parakeet:
      return transcribeParakeet(samples, sampleCount, sampleRate, outText);
    case Backend::None:
      setError("No backend loaded");
      return -1;
  }
  return -1;
}
