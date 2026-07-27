import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// FFI bindings for fluidvoice_speech.dll (speech_runtime facade).
class SpeechRuntimeBinding {
  SpeechRuntimeBinding._(this._lib);

  final DynamicLibrary _lib;

  late final int Function() _init =
      _lib.lookupFunction<Int32 Function(), int Function()>('fv_speech_init');
  late final void Function() _shutdown =
      _lib.lookupFunction<Void Function(), void Function()>('fv_speech_shutdown');
  late final int Function(Pointer<Utf8>) _prepare = _lib.lookupFunction<
      Int32 Function(Pointer<Utf8>),
      int Function(Pointer<Utf8>)>('fv_speech_prepare');
  late final int Function(
          Pointer<Float>, int, int, Pointer<Pointer<Utf8>>) _transcribe =
      _lib.lookupFunction<
          Int32 Function(Pointer<Float>, Int32, Int32, Pointer<Pointer<Utf8>>),
          int Function(Pointer<Float>, int, int,
              Pointer<Pointer<Utf8>>)>('fv_speech_transcribe');
  late final void Function(Pointer<Void>) _free = _lib.lookupFunction<
      Void Function(Pointer<Void>),
      void Function(Pointer<Void>)>('fv_speech_free');
  late final Pointer<Utf8> Function() _lastError = _lib.lookupFunction<
      Pointer<Utf8> Function(),
      Pointer<Utf8> Function()>('fv_speech_last_error');

  static SpeechRuntimeBinding? tryOpen() {
    if (!Platform.isWindows) {
      return null;
    }
    try {
      return SpeechRuntimeBinding._(
        DynamicLibrary.open('fluidvoice_speech.dll'),
      );
    } catch (_) {
      return null;
    }
  }

  void init() {
    final code = _init();
    if (code != 0) {
      throw StateError('fv_speech_init failed (${lastError()})');
    }
  }

  void shutdown() => _shutdown();

  void prepare(String modelPath) {
    final pathPtr = modelPath.toNativeUtf8();
    try {
      final code = _prepare(pathPtr);
      if (code != 0) {
        throw StateError('fv_speech_prepare failed (${lastError()})');
      }
    } finally {
      malloc.free(pathPtr);
    }
  }

  String transcribe(List<double> samples, {int sampleRate = 16000}) {
    if (samples.isEmpty) {
      return '';
    }
    final floats = Float32List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      floats[i] = samples[i].toDouble();
    }
    return transcribeFloats(floats, sampleRate: sampleRate);
  }

  String transcribeFloats(Float32List samples, {int sampleRate = 16000}) {
    if (samples.isEmpty) {
      return '';
    }
    final data = calloc<Float>(samples.length);
    final outPtr = calloc<Pointer<Utf8>>();
    try {
      data.asTypedList(samples.length).setAll(0, samples);
      final code = _transcribe(data, samples.length, sampleRate, outPtr);
      if (code != 0) {
        throw StateError('fv_speech_transcribe failed (${lastError()})');
      }
      final textPtr = outPtr.value;
      if (textPtr == nullptr) {
        return '';
      }
      final text = textPtr.toDartString();
      _free(textPtr.cast());
      return text;
    } finally {
      calloc.free(data);
      calloc.free(outPtr);
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
