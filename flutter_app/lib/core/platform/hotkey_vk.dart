import 'package:flutter/services.dart';

import '../models/hotkey_models.dart';

/// Maps a Flutter logical key to a Win32 virtual-key code, or null if unsupported.
int? vkFromLogicalKey(LogicalKeyboardKey key) {
  final id = key.keyId;

  if (id >= LogicalKeyboardKey.keyA.keyId &&
      id <= LogicalKeyboardKey.keyZ.keyId) {
    return 0x41 + (id - LogicalKeyboardKey.keyA.keyId).toInt();
  }
  if (id >= LogicalKeyboardKey.digit0.keyId &&
      id <= LogicalKeyboardKey.digit9.keyId) {
    return 0x30 + (id - LogicalKeyboardKey.digit0.keyId).toInt();
  }
  if (id >= LogicalKeyboardKey.f1.keyId && id <= LogicalKeyboardKey.f24.keyId) {
    return 0x70 + (id - LogicalKeyboardKey.f1.keyId).toInt();
  }

  final map = <LogicalKeyboardKey, int>{
    LogicalKeyboardKey.space: 0x20,
    LogicalKeyboardKey.enter: 0x0D,
    LogicalKeyboardKey.tab: 0x09,
    LogicalKeyboardKey.escape: 0x1B,
    LogicalKeyboardKey.backspace: 0x08,
    LogicalKeyboardKey.delete: 0x2E,
    LogicalKeyboardKey.insert: 0x2D,
    LogicalKeyboardKey.home: 0x24,
    LogicalKeyboardKey.end: 0x23,
    LogicalKeyboardKey.pageUp: 0x21,
    LogicalKeyboardKey.pageDown: 0x22,
    LogicalKeyboardKey.arrowLeft: 0x25,
    LogicalKeyboardKey.arrowUp: 0x26,
    LogicalKeyboardKey.arrowRight: 0x27,
    LogicalKeyboardKey.arrowDown: 0x28,
    LogicalKeyboardKey.minus: 0xBD,
    LogicalKeyboardKey.equal: 0xBB,
    LogicalKeyboardKey.bracketLeft: 0xDB,
    LogicalKeyboardKey.bracketRight: 0xDD,
    LogicalKeyboardKey.backslash: 0xDC,
    LogicalKeyboardKey.semicolon: 0xBA,
    LogicalKeyboardKey.quote: 0xDE,
    LogicalKeyboardKey.comma: 0xBC,
    LogicalKeyboardKey.period: 0xBE,
    LogicalKeyboardKey.slash: 0xBF,
    LogicalKeyboardKey.backquote: 0xC0,
  };
  return map[key];
}

bool isModifierLogicalKey(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.control ||
      key == LogicalKeyboardKey.controlLeft ||
      key == LogicalKeyboardKey.controlRight ||
      key == LogicalKeyboardKey.shift ||
      key == LogicalKeyboardKey.shiftLeft ||
      key == LogicalKeyboardKey.shiftRight ||
      key == LogicalKeyboardKey.alt ||
      key == LogicalKeyboardKey.altLeft ||
      key == LogicalKeyboardKey.altRight ||
      key == LogicalKeyboardKey.meta ||
      key == LogicalKeyboardKey.metaLeft ||
      key == LogicalKeyboardKey.metaRight ||
      key == LogicalKeyboardKey.superKey;
}

Set<HotkeyModifier> modifiersFromKeyboard(HardwareKeyboard keyboard) {
  final mods = <HotkeyModifier>{};
  if (keyboard.isControlPressed) mods.add(HotkeyModifier.control);
  if (keyboard.isAltPressed) mods.add(HotkeyModifier.alt);
  if (keyboard.isShiftPressed) mods.add(HotkeyModifier.shift);
  if (keyboard.isMetaPressed) {
    mods.add(HotkeyModifier.win);
    mods.add(HotkeyModifier.meta);
  }
  return mods;
}

String formatHotkeyShortcut(HotkeyShortcut shortcut) {
  if (shortcut.label != null && shortcut.label!.trim().isNotEmpty) {
    return shortcut.label!.trim();
  }
  final parts = <String>[];
  if (shortcut.modifiers.contains(HotkeyModifier.control)) parts.add('Ctrl');
  if (shortcut.modifiers.contains(HotkeyModifier.alt)) parts.add('Alt');
  if (shortcut.modifiers.contains(HotkeyModifier.shift)) parts.add('Shift');
  if (shortcut.modifiers.contains(HotkeyModifier.win) ||
      shortcut.modifiers.contains(HotkeyModifier.meta)) {
    parts.add('Win');
  }
  parts.add(_vkLabel(shortcut.keyCode));
  return parts.join(' + ');
}

String _vkLabel(int vk) {
  if (vk >= 0x30 && vk <= 0x39) return String.fromCharCode(vk);
  if (vk >= 0x41 && vk <= 0x5A) return String.fromCharCode(vk);
  if (vk >= 0x70 && vk <= 0x87) return 'F${vk - 0x6F}';
  const named = <int, String>{
    0x20: 'Space',
    0x0D: 'Enter',
    0x09: 'Tab',
    0x1B: 'Esc',
    0x08: 'Backspace',
    0x2E: 'Delete',
    0x2D: 'Insert',
    0x24: 'Home',
    0x23: 'End',
    0x21: 'Page Up',
    0x22: 'Page Down',
    0x25: 'Left',
    0x26: 'Up',
    0x27: 'Right',
    0x28: 'Down',
  };
  return named[vk] ?? 'VK 0x${vk.toRadixString(16).toUpperCase()}';
}

int encodeHotkeyModifiers(Set<HotkeyModifier> mods) {
  var bits = 0;
  if (mods.contains(HotkeyModifier.control)) bits |= 0x0001;
  if (mods.contains(HotkeyModifier.alt)) bits |= 0x0002;
  if (mods.contains(HotkeyModifier.shift)) bits |= 0x0004;
  if (mods.contains(HotkeyModifier.win) || mods.contains(HotkeyModifier.meta)) {
    bits |= 0x0008;
  }
  return bits;
}

Set<HotkeyModifier> decodeHotkeyModifiers(int bits) {
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
