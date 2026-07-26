#include "audio_resample.h"

void stereo48kToMono16k(const int16_t* stereo48k, size_t frames48k,
                        std::vector<int16_t>& mono16k) {
  const size_t outFrames = frames48k / 3;
  mono16k.resize(outFrames);
  for (size_t i = 0; i < outFrames; ++i) {
    const size_t source = i * 3;
    int32_t sum = 0;
    for (size_t j = 0; j < 3; ++j) {
      const int16_t left = stereo48k[(source + j) * 2];
      const int16_t right = stereo48k[(source + j) * 2 + 1];
      sum += (static_cast<int32_t>(left) + static_cast<int32_t>(right)) / 2;
    }
    mono16k[i] = static_cast<int16_t>(sum / 3);
  }
}

void int16ToFloat(const int16_t* input, size_t count, float* output) {
  constexpr float kScale = 1.0f / 32768.0f;
  for (size_t i = 0; i < count; ++i) {
    output[i] = static_cast<float>(input[i]) * kScale;
  }
}
