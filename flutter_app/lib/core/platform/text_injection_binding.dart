import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// FFI bindings for fluidvoice_inject.dll.
class TextInjectionBinding {
  TextInjectionBinding._(this._lib);

  final DynamicLibrary _lib;

  late final int Function(Pointer<Utf8>) _inject = _lib.lookupFunction<
      Int32 Function(Pointer<Utf8>),
      int Function(Pointer<Utf8>)>('fv_inject_text');
  late final int Function(Pointer<Pointer<Utf8>>) _readSelection =
      _lib.lookupFunction<Int32 Function(Pointer<Pointer<Utf8>>),
          int Function(Pointer<Pointer<Utf8>>)>('fv_inject_read_selection');
  late final void Function(Pointer<Void>) _free = _lib.lookupFunction<
      Void Function(Pointer<Void>),
      void Function(Pointer<Void>)>('fv_inject_free');
  late final Pointer<Utf8> Function() _lastError = _lib.lookupFunction<
      Pointer<Utf8> Function(),
      Pointer<Utf8> Function()>('fv_inject_last_error');

  static TextInjectionBinding? tryOpen() {
    if (!Platform.isWindows) {
      return null;
    }
    try {
      return TextInjectionBinding._(
        DynamicLibrary.open('fluidvoice_inject.dll'),
      );
    } catch (_) {
      return null;
    }
  }

  void injectText(String text) {
    final ptr = text.toNativeUtf8();
    try {
      final code = _inject(ptr);
      if (code != 0) {
        throw StateError('fv_inject_text failed (${lastError()})');
      }
    } finally {
      malloc.free(ptr);
    }
  }

  String? readSelection() {
    final outPtr = calloc<Pointer<Utf8>>();
    try {
      final code = _readSelection(outPtr);
      if (code != 0) {
        return null;
      }
      final textPtr = outPtr.value;
      if (textPtr == nullptr) {
        return '';
      }
      final text = textPtr.toDartString();
      _free(textPtr.cast());
      return text;
    } finally {
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
