import '../models/audio_models.dart';

/// Platform audio capture. Windows implements via WASAPI FFI.
///
/// PCM must never cross MethodChannels. See docs/PLUGIN_API.md.
abstract class AudioCapture {
  Stream<AudioChunk> get audioStream;

  Future<List<AudioDeviceInfo>> listDevices();

  Future<void> setDevice(String deviceId);

  Future<void> start();

  Future<void> stop();

  Future<void> dispose();
}
