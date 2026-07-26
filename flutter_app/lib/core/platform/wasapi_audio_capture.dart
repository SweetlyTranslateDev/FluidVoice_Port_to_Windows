import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../interfaces/audio_capture.dart';
import '../models/audio_models.dart';
import 'wasapi_audio_binding.dart';

/// Windows [AudioCapture] backed by WASAPI FFI (poll worker ring → Dart stream).
///
/// Pipeline (native): capture thread → lock-free ring → worker → output ring.
/// Dart never receives audio on a MethodChannel.
class WasapiAudioCapture implements AudioCapture {
  WasapiAudioCapture({WasapiAudioBinding? binding})
      : _binding = binding ?? WasapiAudioBinding.tryOpen();

  final WasapiAudioBinding? _binding;
  final _controller = StreamController<AudioChunk>.broadcast();

  Timer? _pollTimer;
  Pointer<Float>? _readBuffer;
  static const int _pollCapacity = 3200; // 200ms @ 16 kHz
  bool _initialized = false;
  String? _deviceId;

  bool get isNativeAvailable => _binding != null;

  @override
  Stream<AudioChunk> get audioStream => _controller.stream;

  void _ensureInit() {
    final binding = _binding;
    if (binding == null) {
      throw StateError(
        'fluidvoice_wasapi.dll not found. Build native_plugins/wasapi_audio.',
      );
    }
    if (!_initialized) {
      binding.init();
      _initialized = true;
    }
  }

  @override
  Future<List<AudioDeviceInfo>> listDevices() async {
    _ensureInit();
    final devices = _binding!.enumerateDevices();
    return [
      for (final d in devices)
        AudioDeviceInfo(id: d.id, name: d.name, isDefault: d.isDefault),
    ];
  }

  @override
  Future<void> setDevice(String deviceId) async {
    _ensureInit();
    _deviceId = deviceId;
    _binding!.setDevice(deviceId);
  }

  @override
  Future<void> start() async {
    _ensureInit();
    final binding = _binding!;
    binding.setDevice(_deviceId);
    binding.start();

    _readBuffer ??= calloc<Float>(_pollCapacity);
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 20), (_) {
      _poll();
    });
  }

  void _poll() {
    final binding = _binding;
    final buffer = _readBuffer;
    if (binding == null || buffer == null) {
      return;
    }
    try {
      final count = binding.readFloats(buffer, _pollCapacity);
      if (count <= 0) {
        return;
      }
      final samples = List<double>.generate(
        count,
        (i) => buffer[i].toDouble(),
        growable: false,
      );
      if (!_controller.isClosed) {
        _controller.add(
          AudioChunk(
            samples: samples,
            sampleRate: 16000,
            channels: 1,
            isFloat32: true,
          ),
        );
      }
    } catch (e, st) {
      if (!_controller.isClosed) {
        _controller.addError(e, st);
      }
    }
  }

  @override
  Future<void> stop() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _binding?.stop();
  }

  @override
  Future<void> dispose() async {
    await stop();
    if (_initialized) {
      _binding?.shutdown();
      _initialized = false;
    }
    final buffer = _readBuffer;
    if (buffer != null) {
      calloc.free(buffer);
      _readBuffer = null;
    }
    await _controller.close();
  }
}
