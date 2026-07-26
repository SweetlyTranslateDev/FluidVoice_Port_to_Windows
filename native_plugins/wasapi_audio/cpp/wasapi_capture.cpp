#include "wasapi_capture.h"

#include <avrt.h>
#include <cstring>
#include <vector>

#pragma comment(lib, "avrt.lib")
#pragma comment(lib, "ole32.lib")

WasapiCapture::WasapiCapture() {
  m_eventHandle = CreateEventW(nullptr, FALSE, FALSE, nullptr);
}

WasapiCapture::~WasapiCapture() {
  close();
  if (m_eventHandle) {
    CloseHandle(m_eventHandle);
    m_eventHandle = nullptr;
  }
}

int WasapiCapture::open(const std::string& deviceId, RingBuffer* outputBuffer,
                        int sampleRate, int channelCount) {
  m_outputBuffer = outputBuffer;
  m_sampleRate = sampleRate;
  m_channelCount = channelCount;

  IMMDeviceEnumerator* enumerator = nullptr;
  HRESULT hr = CoCreateInstance(
      __uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
      __uuidof(IMMDeviceEnumerator),
      reinterpret_cast<void**>(&enumerator));
  if (FAILED(hr)) {
    return static_cast<int>(hr);
  }

  if (deviceId.empty()) {
    hr = enumerator->GetDefaultAudioEndpoint(eCapture, eConsole, &m_device);
  } else {
    const int wlen =
        MultiByteToWideChar(CP_UTF8, 0, deviceId.c_str(), -1, nullptr, 0);
    std::vector<wchar_t> wideId(static_cast<size_t>(wlen));
    MultiByteToWideChar(CP_UTF8, 0, deviceId.c_str(), -1, wideId.data(), wlen);
    hr = enumerator->GetDevice(wideId.data(), &m_device);
  }
  enumerator->Release();
  if (FAILED(hr)) {
    return static_cast<int>(hr);
  }

  hr = m_device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                          reinterpret_cast<void**>(&m_audioClient));
  if (FAILED(hr)) {
    return static_cast<int>(hr);
  }

  WAVEFORMATEX wfx = {};
  wfx.wFormatTag = WAVE_FORMAT_PCM;
  wfx.nChannels = static_cast<WORD>(m_channelCount);
  wfx.nSamplesPerSec = static_cast<DWORD>(m_sampleRate);
  wfx.wBitsPerSample = static_cast<WORD>(m_bitsPerSample);
  wfx.nBlockAlign =
      static_cast<WORD>(wfx.nChannels * wfx.wBitsPerSample / 8);
  wfx.nAvgBytesPerSec = wfx.nSamplesPerSec * wfx.nBlockAlign;

  // AUTOCONVERTPCM: Windows converts device mix format to our PCM request.
  // Without it, shared-mode Initialize often fails or yields float mismatch.
  const DWORD streamFlags = AUDCLNT_STREAMFLAGS_EVENTCALLBACK |
                            AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM |
                            AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY;
  constexpr REFERENCE_TIME kBufferDuration = 100000;  // 10ms

  hr = m_audioClient->Initialize(AUDCLNT_SHAREMODE_SHARED, streamFlags,
                                 kBufferDuration, 0, &wfx, nullptr);
  if (FAILED(hr)) {
    WAVEFORMATEX* mixFormat = nullptr;
    m_audioClient->GetMixFormat(&mixFormat);
    if (mixFormat) {
      hr = m_audioClient->Initialize(AUDCLNT_SHAREMODE_SHARED,
                                     AUDCLNT_STREAMFLAGS_EVENTCALLBACK,
                                     kBufferDuration, 0, mixFormat, nullptr);
      m_sampleRate = static_cast<int>(mixFormat->nSamplesPerSec);
      m_channelCount = mixFormat->nChannels;
      m_bitsPerSample = mixFormat->wBitsPerSample;
      CoTaskMemFree(mixFormat);
    }
    if (FAILED(hr)) {
      return static_cast<int>(hr);
    }
  }

  hr = m_audioClient->SetEventHandle(m_eventHandle);
  if (FAILED(hr)) {
    return static_cast<int>(hr);
  }

  hr = m_audioClient->GetBufferSize(&m_bufferFrameCount);
  if (FAILED(hr)) {
    return static_cast<int>(hr);
  }

  hr = m_audioClient->GetService(__uuidof(IAudioCaptureClient),
                                  reinterpret_cast<void**>(&m_captureClient));
  if (FAILED(hr)) {
    return static_cast<int>(hr);
  }

  return 0;
}

int WasapiCapture::start() {
  if (!m_audioClient || !m_captureClient) {
    return -1;
  }
  if (m_running.load()) {
    return 0;
  }

  m_shouldStop.store(false);
  HRESULT hr = m_audioClient->Start();
  if (FAILED(hr)) {
    return static_cast<int>(hr);
  }

  m_running.store(true);
  m_thread = std::thread(&WasapiCapture::captureThread, this);
  return 0;
}

void WasapiCapture::stop() {
  m_shouldStop.store(true);
  if (m_thread.joinable()) {
    SetEvent(m_eventHandle);
    m_thread.join();
  }
  if (m_audioClient) {
    m_audioClient->Stop();
  }
  m_running.store(false);
}

void WasapiCapture::close() {
  stop();
  if (m_captureClient) {
    m_captureClient->Release();
    m_captureClient = nullptr;
  }
  if (m_audioClient) {
    m_audioClient->Release();
    m_audioClient = nullptr;
  }
  if (m_device) {
    m_device->Release();
    m_device = nullptr;
  }
}

void WasapiCapture::setErrorCallback(std::function<void(const std::string&)> cb) {
  m_errorCb = std::move(cb);
}

void WasapiCapture::captureThread() {
  // Capture thread only writes the ring buffer — never calls into Dart.
  DWORD taskIndex = 0;
  HANDLE task = AvSetMmThreadCharacteristicsW(L"Audio", &taskIndex);

  while (!m_shouldStop.load()) {
    const DWORD waitResult = WaitForSingleObject(m_eventHandle, 100);
    if (m_shouldStop.load()) {
      break;
    }
    if (waitResult != WAIT_OBJECT_0) {
      continue;
    }

    UINT32 packetLength = 0;
    HRESULT hr = m_captureClient->GetNextPacketSize(&packetLength);
    if (FAILED(hr)) {
      if (m_errorCb) {
        m_errorCb("GetNextPacketSize failed");
      }
      break;
    }

    while (packetLength > 0) {
      BYTE* data = nullptr;
      UINT32 framesAvailable = 0;
      DWORD flags = 0;

      hr = m_captureClient->GetBuffer(&data, &framesAvailable, &flags, nullptr,
                                      nullptr);
      if (FAILED(hr)) {
        if (m_errorCb) {
          m_errorCb("GetBuffer failed");
        }
        break;
      }

      if (flags & AUDCLNT_BUFFERFLAGS_SILENT) {
        std::vector<uint8_t> silence(
            framesAvailable * m_channelCount * m_bitsPerSample / 8, 0);
        if (m_outputBuffer) {
          m_outputBuffer->write(silence.data(), framesAvailable);
        }
      } else if (m_outputBuffer && data) {
        m_outputBuffer->write(data, framesAvailable);
      }

      m_captureClient->ReleaseBuffer(framesAvailable);
      hr = m_captureClient->GetNextPacketSize(&packetLength);
      if (FAILED(hr)) {
        break;
      }
    }
  }

  if (task) {
    AvRevertMmThreadCharacteristics(task);
  }
  m_running.store(false);
}
