#include "device_enumerator.h"

#include <Functiondiscoverykeys_devpkey.h>

DeviceEnumerator::DeviceEnumerator() = default;

DeviceEnumerator::~DeviceEnumerator() { shutdown(); }

int DeviceEnumerator::init() {
  HRESULT hr = CoCreateInstance(
      __uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
      __uuidof(IMMDeviceEnumerator),
      reinterpret_cast<void**>(&m_enumerator));
  return FAILED(hr) ? static_cast<int>(hr) : 0;
}

void DeviceEnumerator::shutdown() {
  if (m_enumerator) {
    m_enumerator->Release();
    m_enumerator = nullptr;
  }
}

std::string DeviceEnumerator::getDefaultCaptureId() {
  if (!m_enumerator) {
    return {};
  }
  IMMDevice* device = nullptr;
  HRESULT hr =
      m_enumerator->GetDefaultAudioEndpoint(eCapture, eConsole, &device);
  if (FAILED(hr) || !device) {
    return {};
  }
  LPWSTR deviceId = nullptr;
  hr = device->GetId(&deviceId);
  std::string result;
  if (SUCCEEDED(hr) && deviceId) {
    result = wideToUtf8(deviceId);
    CoTaskMemFree(deviceId);
  }
  device->Release();
  return result;
}

std::vector<CaptureDeviceInfo> DeviceEnumerator::enumerateCapture() {
  std::vector<CaptureDeviceInfo> devices;
  if (!m_enumerator) {
    return devices;
  }

  const std::string defaultId = getDefaultCaptureId();

  IMMDeviceCollection* collection = nullptr;
  HRESULT hr = m_enumerator->EnumAudioEndpoints(eCapture, DEVICE_STATE_ACTIVE,
                                                &collection);
  if (FAILED(hr) || !collection) {
    return devices;
  }

  UINT count = 0;
  collection->GetCount(&count);
  for (UINT i = 0; i < count; ++i) {
    IMMDevice* device = nullptr;
    hr = collection->Item(i, &device);
    if (FAILED(hr) || !device) {
      continue;
    }

    LPWSTR deviceId = nullptr;
    hr = device->GetId(&deviceId);
    if (FAILED(hr) || !deviceId) {
      device->Release();
      continue;
    }

    IPropertyStore* props = nullptr;
    hr = device->OpenPropertyStore(STGM_READ, &props);
    std::string friendlyName = "Unknown Device";
    if (SUCCEEDED(hr) && props) {
      PROPVARIANT varName;
      PropVariantInit(&varName);
      hr = props->GetValue(PKEY_Device_FriendlyName, &varName);
      if (SUCCEEDED(hr) && varName.vt == VT_LPWSTR) {
        friendlyName = wideToUtf8(varName.pwszVal);
      }
      PropVariantClear(&varName);
      props->Release();
    }

    CaptureDeviceInfo info;
    info.id = wideToUtf8(deviceId);
    info.name = friendlyName;
    info.isDefault = (info.id == defaultId);
    devices.push_back(info);

    CoTaskMemFree(deviceId);
    device->Release();
  }

  collection->Release();
  return devices;
}

std::string DeviceEnumerator::wideToUtf8(const wchar_t* wide) {
  if (!wide) {
    return {};
  }
  const int len =
      WideCharToMultiByte(CP_UTF8, 0, wide, -1, nullptr, 0, nullptr, nullptr);
  if (len <= 0) {
    return {};
  }
  std::string result(static_cast<size_t>(len - 1), '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide, -1, result.data(), len, nullptr,
                      nullptr);
  return result;
}
