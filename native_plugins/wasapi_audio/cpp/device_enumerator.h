#pragma once

#include <mmdeviceapi.h>
#include <string>
#include <vector>

struct CaptureDeviceInfo {
  std::string id;
  std::string name;
  bool isDefault = false;
};

class DeviceEnumerator {
public:
  DeviceEnumerator();
  ~DeviceEnumerator();

  DeviceEnumerator(const DeviceEnumerator&) = delete;
  DeviceEnumerator& operator=(const DeviceEnumerator&) = delete;

  int init();
  void shutdown();

  std::vector<CaptureDeviceInfo> enumerateCapture();
  std::string getDefaultCaptureId();

private:
  IMMDeviceEnumerator* m_enumerator = nullptr;
  static std::string wideToUtf8(const wchar_t* wide);
};
