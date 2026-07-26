/**
 * Lock-free single-producer single-consumer ring buffer.
 * Adapted from Sweetly production audio (reference only; lives in FluidVoice tree).
 */

#pragma once

#include <atomic>
#include <cstddef>
#include <cstdint>
#include <vector>

class RingBuffer {
public:
  RingBuffer(size_t capacityFrames, int channelCount = 2, int bytesPerSample = 2);
  ~RingBuffer() = default;

  RingBuffer(const RingBuffer&) = delete;
  RingBuffer& operator=(const RingBuffer&) = delete;

  size_t write(const void* data, size_t frameCount);
  size_t read(void* data, size_t frameCount);
  size_t availableRead() const;
  size_t availableWrite() const;
  void clear();

  size_t frameSize() const { return m_frameSize; }
  size_t capacity() const { return m_capacity; }

  uint64_t writeDrops() const {
    return m_writeDrops.load(std::memory_order_relaxed);
  }

private:
  std::vector<uint8_t> m_buffer;
  size_t m_capacity = 0;
  size_t m_frameSize = 0;
  std::atomic<size_t> m_writePos{0};
  std::atomic<size_t> m_readPos{0};
  std::atomic<uint64_t> m_writeDrops{0};
};
