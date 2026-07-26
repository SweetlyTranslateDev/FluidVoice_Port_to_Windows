import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// FFI bindings for fluidvoice_hotkeys.dll.
class HotkeysBinding {
  HotkeysBinding._(this._lib);

  final DynamicLibrary _lib;

  late final int Function() _init =
      _lib.lookupFunction<Int32 Function(), int Function()>('fv_hotkey_init');
  late final void Function() _shutdown =
      _lib.lookupFunction<Void Function(), void Function()>('fv_hotkey_shutdown');
  late final int Function(int, int) _setShortcut = _lib.lookupFunction<
      Int32 Function(Int32, Int32), int Function(int, int)>(
    'fv_hotkey_set_shortcut',
  );
  late final int Function() _start =
      _lib.lookupFunction<Int32 Function(), int Function()>('fv_hotkey_start');
  late final int Function() _stop =
      _lib.lookupFunction<Int32 Function(), int Function()>('fv_hotkey_stop');
  late final int Function(Pointer<FvHotkeyEvent>, int, Pointer<Int32>) _poll =
      _lib.lookupFunction<
          Int32 Function(Pointer<FvHotkeyEvent>, Int32, Pointer<Int32>),
          int Function(Pointer<FvHotkeyEvent>, int, Pointer<Int32>)>(
    'fv_hotkey_poll',
  );
  late final Pointer<Utf8> Function() _lastError = _lib.lookupFunction<
      Pointer<Utf8> Function(),
      Pointer<Utf8> Function()>('fv_hotkey_last_error');

  static HotkeysBinding? tryOpen() {
    if (!Platform.isWindows) {
      return null;
    }
    try {
      return HotkeysBinding._(DynamicLibrary.open('fluidvoice_hotkeys.dll'));
    } catch (_) {
      return null;
    }
  }

  void init() {
    final code = _init();
    if (code != 0) {
      throw StateError('fv_hotkey_init failed (${lastError()})');
    }
  }

  void shutdown() => _shutdown();

  void setShortcut({required int vkCode, required int modifiers}) {
    final code = _setShortcut(vkCode, modifiers);
    if (code != 0) {
      throw StateError('fv_hotkey_set_shortcut failed (${lastError()})');
    }
  }

  void start() {
    final code = _start();
    if (code != 0) {
      throw StateError('fv_hotkey_start failed (${lastError()})');
    }
  }

  void stop() => _stop();

  int poll(Pointer<FvHotkeyEvent> buffer, int maxEvents) {
    final countPtr = calloc<Int32>();
    try {
      final code = _poll(buffer, maxEvents, countPtr);
      if (code != 0) {
        throw StateError('fv_hotkey_poll failed (${lastError()})');
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

final class FvHotkeyEvent extends Struct {
  @Int32()
  external int type;

  @Int32()
  external int vkCode;

  @Int32()
  external int modifiers;
}
