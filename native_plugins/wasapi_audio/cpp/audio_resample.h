#pragma once

#include <cstddef>
#include <cstdint>
#include <vector>

/** Downmix 48 kHz stereo int16 to 16 kHz mono int16 (3:1 average). */
void stereo48kToMono16k(const int16_t* stereo48k, size_t frames48k,
                        std::vector<int16_t>& mono16k);

/** Convert mono int16 PCM to float32 in [-1, 1]. */
void int16ToFloat(const int16_t* input, size_t count, float* output);
