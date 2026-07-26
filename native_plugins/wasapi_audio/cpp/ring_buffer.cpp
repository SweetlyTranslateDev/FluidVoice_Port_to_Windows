#include "ring_buffer.h"

#include <algorithm>
#include <cstring>

RingBuffer::RingBuffer(size_t capacityFrames, int channelCount, int bytesPerSample)
    : m_capacity(capacityFrames),
      m_frameSize(static_cast<size_t>(channelCount) *
                  static_cast<size_t>(bytesPerSample)) {
  m_buffer.resize((m_capacity + 1) * m_frameSize, 0);
}

size_t RingBuffer::write(const void* data, size_t frameCount) {
  const size_t avail = availableWrite();
  const size_t toWrite = std::min(frameCount, avail);
  if (toWrite == 0) {
    m_writeDrops.fetch_add(static_cast<uint64_t>(frameCount),
                           std::memory_order_relaxed);
    return 0;
  }

  const size_t bufferFrames = m_capacity + 1;
  size_t writePos = m_writePos.load(std::memory_order_relaxed);
  const auto* src = static_cast<const uint8_t*>(data);

  const size_t firstChunk = std::min(toWrite, bufferFrames - writePos);
  std::memcpy(m_buffer.data() + writePos * m_frameSize, src,
              firstChunk * m_frameSize);

  if (firstChunk < toWrite) {
    const size_t secondChunk = toWrite - firstChunk;
    std::memcpy(m_buffer.data(), src + firstChunk * m_frameSize,
                secondChunk * m_frameSize);
  }

  m_writePos.store((writePos + toWrite) % bufferFrames,
                   std::memory_order_release);
  if (toWrite < frameCount) {
    m_writeDrops.fetch_add(static_cast<uint64_t>(frameCount - toWrite),
                           std::memory_order_relaxed);
  }
  return toWrite;
}

size_t RingBuffer::read(void* data, size_t frameCount) {
  const size_t avail = availableRead();
  const size_t toRead = std::min(frameCount, avail);
  if (toRead == 0) {
    return 0;
  }

  const size_t bufferFrames = m_capacity + 1;
  size_t readPos = m_readPos.load(std::memory_order_relaxed);
  auto* dst = static_cast<uint8_t*>(data);

  const size_t firstChunk = std::min(toRead, bufferFrames - readPos);
  std::memcpy(dst, m_buffer.data() + readPos * m_frameSize,
              firstChunk * m_frameSize);

  if (firstChunk < toRead) {
    const size_t secondChunk = toRead - firstChunk;
    std::memcpy(dst + firstChunk * m_frameSize, m_buffer.data(),
                secondChunk * m_frameSize);
  }

  m_readPos.store((readPos + toRead) % bufferFrames, std::memory_order_release);
  return toRead;
}

size_t RingBuffer::availableRead() const {
  const size_t bufferFrames = m_capacity + 1;
  const size_t w = m_writePos.load(std::memory_order_acquire);
  const size_t r = m_readPos.load(std::memory_order_acquire);
  return (w >= r) ? (w - r) : (bufferFrames - r + w);
}

size_t RingBuffer::availableWrite() const {
  return m_capacity - availableRead();
}

void RingBuffer::clear() {
  m_readPos.store(0, std::memory_order_release);
  m_writePos.store(0, std::memory_order_release);
}
