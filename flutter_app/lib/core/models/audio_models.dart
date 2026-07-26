/// Shared audio types for capture and speech pipelines.
library;

class AudioDeviceInfo {
  const AudioDeviceInfo({
    required this.id,
    required this.name,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final bool isDefault;
}

/// One chunk of PCM from the audio worker (prefer mono 16 kHz).
class AudioChunk {
  const AudioChunk({
    required this.samples,
    required this.sampleRate,
    required this.channels,
    this.isFloat32 = true,
  });

  /// Interleaved PCM samples as float32 in [-1, 1] when [isFloat32] is true.
  final List<double> samples;
  final int sampleRate;
  final int channels;
  final bool isFloat32;
}

class AudioBuffer {
  const AudioBuffer({
    required this.samples,
    required this.sampleRate,
    required this.channels,
    this.isFloat32 = true,
  });

  final List<double> samples;
  final int sampleRate;
  final int channels;
  final bool isFloat32;
}
