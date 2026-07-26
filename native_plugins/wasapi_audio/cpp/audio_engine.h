#pragma once

#include "device_enumerator.h"
#include "ring_buffer.h"
#include "wasapi_capture.h"

#include <atomic>
#include <memory>
#include <string>
#include <thread>
#include <vector>

/**
 * Owns WASAPI capture + worker conversion to mono 16 kHz.
 * Capture thread never touches Dart; worker only fills an output ring.
 */
class AudioEngine {
public:
  AudioEngine();
  ~AudioEngine();

  int init();
  void shutdown();

  std::vector<CaptureDeviceInfo> enumerateCaptureDevices();
  int setDevice(const std::string& deviceId);

  int start();
  void stop();

  /** Non-blocking: copy mono float32 @ 16 kHz into out. Returns samples written. */
  int readFloats(float* out, int maxSamples);

  const char* lastError() const { return m_lastError.c_str(); }

private:
  void workerThread();
  void setError(const std::string& msg);

  bool m_initialized = false;
  bool m_comOwned = false;
  bool m_timerPeriodSet = false;

  std::string m_deviceId;
  std::string m_lastError;

  std::unique_ptr<DeviceEnumerator> m_devices;
  std::unique_ptr<RingBuffer> m_captureRing;  // 48k stereo int16
  std::unique_ptr<RingBuffer> m_outputRing;   // 16k mono int16
  std::unique_ptr<WasapiCapture> m_capture;

  std::thread m_worker;
  std::atomic<bool> m_running{false};
  std::atomic<bool> m_shouldStop{false};
};
