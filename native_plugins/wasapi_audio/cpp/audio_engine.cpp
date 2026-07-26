#include "audio_engine.h"

#include "audio_resample.h"

#include <avrt.h>
#include <objbase.h>
#include <timeapi.h>

#include <chrono>
#include <cstring>
#include <vector>

#pragma comment(lib, "winmm.lib")
#pragma comment(lib, "avrt.lib")

namespace {
// 500ms at 48 kHz stereo capture; 2s of 16 kHz mono for Dart poll headroom.
constexpr size_t kCaptureRingFrames = 48000 / 2;
constexpr size_t kOutputRingFrames = 16000 * 2;
constexpr int kWorkerBlockFrames48k = 480;  // 10ms @ 48k
}  // namespace

AudioEngine::AudioEngine() = default;

AudioEngine::~AudioEngine() { shutdown(); }

void AudioEngine::setError(const std::string& msg) { m_lastError = msg; }

int AudioEngine::init() {
  if (m_initialized) {
    return 0;
  }

  timeBeginPeriod(1);
  m_timerPeriodSet = true;

  HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) {
    setError("CoInitializeEx failed");
    timeEndPeriod(1);
    m_timerPeriodSet = false;
    return static_cast<int>(hr);
  }
  // Only uninitialize if this call actually initialized COM on this thread.
  m_comOwned = (hr == S_OK);

  m_devices = std::make_unique<DeviceEnumerator>();
  const int result = m_devices->init();
  if (result != 0) {
    setError("DeviceEnumerator::init failed");
    shutdown();
    return result;
  }

  m_initialized = true;
  return 0;
}

void AudioEngine::shutdown() {
  stop();
  if (m_devices) {
    m_devices->shutdown();
    m_devices.reset();
  }
  if (m_timerPeriodSet) {
    timeEndPeriod(1);
    m_timerPeriodSet = false;
  }
  if (m_comOwned) {
    CoUninitialize();
    m_comOwned = false;
  }
  m_initialized = false;
}

std::vector<CaptureDeviceInfo> AudioEngine::enumerateCaptureDevices() {
  if (!m_devices) {
    return {};
  }
  return m_devices->enumerateCapture();
}

int AudioEngine::setDevice(const std::string& deviceId) {
  if (m_running.load()) {
    setError("Cannot change device while capturing");
    return -1;
  }
  m_deviceId = deviceId;
  return 0;
}

int AudioEngine::start() {
  if (!m_initialized) {
    setError("Audio engine not initialized");
    return -1;
  }
  if (m_running.load()) {
    return 0;
  }

  m_captureRing =
      std::make_unique<RingBuffer>(kCaptureRingFrames, /*ch=*/2, /*bps=*/2);
  m_outputRing =
      std::make_unique<RingBuffer>(kOutputRingFrames, /*ch=*/1, /*bps=*/2);

  m_capture = std::make_unique<WasapiCapture>();
  m_capture->setErrorCallback([this](const std::string& msg) { setError(msg); });

  const int openResult =
      m_capture->open(m_deviceId, m_captureRing.get(), 48000, 2);
  if (openResult != 0) {
    setError("WasapiCapture::open failed");
    m_capture.reset();
    m_captureRing.reset();
    m_outputRing.reset();
    return openResult;
  }

  m_shouldStop.store(false);
  m_running.store(true);
  m_worker = std::thread(&AudioEngine::workerThread, this);

  const int startResult = m_capture->start();
  if (startResult != 0) {
    setError("WasapiCapture::start failed");
    stop();
    return startResult;
  }

  m_lastError.clear();
  return 0;
}

void AudioEngine::stop() {
  m_shouldStop.store(true);
  if (m_capture) {
    m_capture->close();
    m_capture.reset();
  }
  if (m_worker.joinable()) {
    m_worker.join();
  }
  m_running.store(false);
  m_captureRing.reset();
  m_outputRing.reset();
}

int AudioEngine::readFloats(float* out, int maxSamples) {
  if (!out || maxSamples <= 0 || !m_outputRing) {
    return 0;
  }

  std::vector<int16_t> pcm(static_cast<size_t>(maxSamples));
  const size_t got =
      m_outputRing->read(pcm.data(), static_cast<size_t>(maxSamples));
  if (got == 0) {
    return 0;
  }
  int16ToFloat(pcm.data(), got, out);
  return static_cast<int>(got);
}

void AudioEngine::workerThread() {
  // Worker reads capture ring, converts, writes output ring — never calls Dart.
  DWORD taskIndex = 0;
  HANDLE task = AvSetMmThreadCharacteristicsW(L"Pro Audio", &taskIndex);

  std::vector<int16_t> stereo48k(static_cast<size_t>(kWorkerBlockFrames48k) * 2);
  std::vector<int16_t> mono16k;

  while (!m_shouldStop.load()) {
    if (!m_captureRing || !m_outputRing) {
      break;
    }

    if (m_captureRing->availableRead() <
        static_cast<size_t>(kWorkerBlockFrames48k)) {
      std::this_thread::sleep_for(std::chrono::milliseconds(2));
      continue;
    }

    const size_t framesRead = m_captureRing->read(
        stereo48k.data(), static_cast<size_t>(kWorkerBlockFrames48k));
    if (framesRead < 3) {
      continue;
    }

    // Use complete groups of 3 frames for 48k→16k.
    const size_t usable = (framesRead / 3) * 3;
    stereo48kToMono16k(stereo48k.data(), usable, mono16k);
    if (!mono16k.empty()) {
      m_outputRing->write(mono16k.data(), mono16k.size());
    }
  }

  if (task) {
    AvRevertMmThreadCharacteristics(task);
  }
}
