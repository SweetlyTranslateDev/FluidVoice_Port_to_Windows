/**
 * WASAPI shared-mode capture into a ring buffer on a dedicated audio thread.
 * Adapted from Sweetly production WasapiCapture (reference only).
 */

#pragma once

#include "ring_buffer.h"

#include <Audioclient.h>
#include <atomic>
#include <functional>
#include <mmdeviceapi.h>
#include <string>
#include <thread>

class WasapiCapture {
public:
  WasapiCapture();
  ~WasapiCapture();

  WasapiCapture(const WasapiCapture&) = delete;
  WasapiCapture& operator=(const WasapiCapture&) = delete;

  int open(const std::string& deviceId, RingBuffer* outputBuffer,
           int sampleRate = 48000, int channelCount = 2);
  int start();
  void stop();
  void close();

  bool isRunning() const { return m_running.load(); }
  void setErrorCallback(std::function<void(const std::string&)> cb);

private:
  void captureThread();

  IMMDevice* m_device = nullptr;
  IAudioClient* m_audioClient = nullptr;
  IAudioCaptureClient* m_captureClient = nullptr;
  HANDLE m_eventHandle = nullptr;

  RingBuffer* m_outputBuffer = nullptr;
  std::thread m_thread;
  std::atomic<bool> m_running{false};
  std::atomic<bool> m_shouldStop{false};

  int m_sampleRate = 48000;
  int m_channelCount = 2;
  int m_bitsPerSample = 16;
  UINT32 m_bufferFrameCount = 0;

  std::function<void(const std::string&)> m_errorCb;
};
