import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Low-level FFI bindings to fluidvoice_wasapi.dll.
class WasapiAudioBinding {
  WasapiAudioBinding._(this._lib);

  final DynamicLibrary _lib;

  late final int Function() _init =
      _lib.lookupFunction<Int32 Function(), int Function()>('fv_audio_init');
  late final void Function() _shutdown =
      _lib.lookupFunction<Void Function(), void Function()>('fv_audio_shutdown');
  late final Pointer<FvAudioDeviceList> Function() _enumerate = _lib
      .lookupFunction<
          Pointer<FvAudioDeviceList> Function(),
          Pointer<FvAudioDeviceList> Function()>('fv_audio_enumerate_devices');
  late final void Function(Pointer<FvAudioDeviceList>) _freeList =
      _lib.lookupFunction<
          Void Function(Pointer<FvAudioDeviceList>),
          void Function(
              Pointer<FvAudioDeviceList>)>('fv_audio_free_device_list');
  late final int Function(Pointer<Utf8>) _setDevice = _lib.lookupFunction<
      Int32 Function(Pointer<Utf8>),
      int Function(Pointer<Utf8>)>('fv_audio_set_device');
  late final int Function() _start =
      _lib.lookupFunction<Int32 Function(), int Function()>('fv_audio_start');
  late final int Function() _stop =
      _lib.lookupFunction<Int32 Function(), int Function()>('fv_audio_stop');
  late final int Function(Pointer<Float>, int, Pointer<Int32>) _readFloats =
      _lib.lookupFunction<
          Int32 Function(Pointer<Float>, Int32, Pointer<Int32>),
          int Function(
              Pointer<Float>, int, Pointer<Int32>)>('fv_audio_read_floats');
  late final Pointer<Utf8> Function() _lastError = _lib.lookupFunction<
      Pointer<Utf8> Function(),
      Pointer<Utf8> Function()>('fv_audio_last_error');

  static WasapiAudioBinding? tryOpen() {
    if (!Platform.isWindows) {
      return null;
    }
    try {
      return WasapiAudioBinding._(DynamicLibrary.open('fluidvoice_wasapi.dll'));
    } catch (_) {
      return null;
    }
  }

  void init() {
    final code = _init();
    if (code != 0) {
      throw StateError('fv_audio_init failed (${lastError()})');
    }
  }

  void shutdown() => _shutdown();

  List<({String id, String name, bool isDefault})> enumerateDevices() {
    final ptr = _enumerate();
    if (ptr == nullptr) {
      throw StateError('fv_audio_enumerate_devices failed (${lastError()})');
    }
    try {
      final list = ptr.ref;
      final result = <({String id, String name, bool isDefault})>[];
      for (var i = 0; i < list.count; i++) {
        final d = (list.devices + i).ref;
        result.add((
          id: d.id.toDartString(),
          name: d.name.toDartString(),
          isDefault: d.isDefault != 0,
        ));
      }
      return result;
    } finally {
      _freeList(ptr);
    }
  }

  void setDevice(String? deviceId) {
    if (deviceId == null || deviceId.isEmpty) {
      final code = _setDevice(nullptr);
      if (code != 0) {
        throw StateError('fv_audio_set_device failed (${lastError()})');
      }
      return;
    }
    final ptr = deviceId.toNativeUtf8();
    try {
      final code = _setDevice(ptr);
      if (code != 0) {
        throw StateError('fv_audio_set_device failed (${lastError()})');
      }
    } finally {
      malloc.free(ptr);
    }
  }

  void start() {
    final code = _start();
    if (code != 0) {
      throw StateError('fv_audio_start failed (${lastError()})');
    }
  }

  void stop() => _stop();

  int readFloats(Pointer<Float> buffer, int maxSamples) {
    final countPtr = calloc<Int32>();
    try {
      final code = _readFloats(buffer, maxSamples, countPtr);
      if (code != 0) {
        throw StateError('fv_audio_read_floats failed (${lastError()})');
      }
      return countPtr.value;
    } finally {
      calloc.free(countPtr);
    }
  }

  String lastError() {
    final ptr = _lastError();
    if (ptr == nullptr) {
      return '';
    }
    return ptr.toDartString();
  }
}

final class FvAudioDevice extends Struct {
  external Pointer<Utf8> id;
  external Pointer<Utf8> name;

  @Int32()
  external int isDefault;
}

final class FvAudioDeviceList extends Struct {
  external Pointer<FvAudioDevice> devices;

  @Int32()
  external int count;
}
