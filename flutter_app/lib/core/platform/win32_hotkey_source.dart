import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../interfaces/hotkey_source.dart';
import '../models/hotkey_models.dart';
import 'hotkeys_binding.dart';

/// [HotkeySource] backed by WH_KEYBOARD_LL via fluidvoice_hotkeys.dll.
class Win32HotkeySource implements HotkeySource {
  Win32HotkeySource({HotkeysBinding? binding})
      : _binding = binding ?? HotkeysBinding.tryOpen();

  final HotkeysBinding? _binding;
  final _controller = StreamController<HotkeyEvent>.broadcast();

  Timer? _pollTimer;
  Pointer<FvHotkeyEvent>? _eventBuffer;
  static const int _pollCapacity = 32;
  bool _initialized = false;
  HotkeyShortcut? _shortcut;

  bool get isNativeAvailable => _binding != null;

  @override
  Stream<HotkeyEvent> get events => _controller.stream;

  void _ensureInit() {
    final binding = _binding;
    if (binding == null) {
      throw StateError(
        'fluidvoice_hotkeys.dll not found. Build Flutter Windows to produce it.',
      );
    }
    if (!_initialized) {
      binding.init();
      _initialized = true;
    }
  }

  @override
  Future<void> setShortcut(HotkeyShortcut shortcut) async {
    _ensureInit();
    _shortcut = shortcut;
    _binding!.setShortcut(
      vkCode: shortcut.keyCode,
      modifiers: _encodeModifiers(shortcut.modifiers),
    );
  }

  @override
  Future<void> start() async {
    _ensureInit();
    // Default to F8 PTT if caller forgot setShortcut().
    await setShortcut(_shortcut ?? kDefaultHotkeyShortcut);
    _binding!.start();

    _eventBuffer ??= calloc<FvHotkeyEvent>(_pollCapacity);
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      _poll();
    });
  }

  void _poll() {
    final binding = _binding;
    final buffer = _eventBuffer;
    if (binding == null || buffer == null) {
      return;
    }
    try {
      final count = binding.poll(buffer, _pollCapacity);
      for (var i = 0; i < count; i++) {
        final raw = (buffer + i).ref;
        if (!_controller.isClosed) {
          _controller.add(
            HotkeyEvent(
              type: raw.type == 2
                  ? HotkeyEventType.keyUp
                  : HotkeyEventType.keyDown,
              keyCode: raw.vkCode,
              modifiers: _decodeModifiers(raw.modifiers),
            ),
          );
        }
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

  Future<void> dispose() async {
    await stop();
    if (_initialized) {
      _binding?.shutdown();
      _initialized = false;
    }
    final buffer = _eventBuffer;
    if (buffer != null) {
      calloc.free(buffer);
      _eventBuffer = null;
    }
    await _controller.close();
  }

  static int _encodeModifiers(Set<HotkeyModifier> mods) {
    var bits = 0;
    if (mods.contains(HotkeyModifier.control)) bits |= 0x0001;
    if (mods.contains(HotkeyModifier.alt)) bits |= 0x0002;
    if (mods.contains(HotkeyModifier.shift)) bits |= 0x0004;
    if (mods.contains(HotkeyModifier.win) || mods.contains(HotkeyModifier.meta)) {
      bits |= 0x0008;
    }
    return bits;
  }

  static Set<HotkeyModifier> _decodeModifiers(int bits) {
    final mods = <HotkeyModifier>{};
    if (bits & 0x0001 != 0) mods.add(HotkeyModifier.control);
    if (bits & 0x0002 != 0) mods.add(HotkeyModifier.alt);
    if (bits & 0x0004 != 0) mods.add(HotkeyModifier.shift);
    if (bits & 0x0008 != 0) {
      mods.add(HotkeyModifier.win);
      mods.add(HotkeyModifier.meta);
    }
    return mods;
  }
}

/// Default dictation hotkey: F8 (push-to-talk).
const HotkeyShortcut kDefaultHotkeyShortcut = HotkeyShortcut(
  keyCode: 0x77, // VK_F8
  label: 'F8',
);
