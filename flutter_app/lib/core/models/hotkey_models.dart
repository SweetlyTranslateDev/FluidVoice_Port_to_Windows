library;

enum HotkeyActivationMode {
  pushToTalk,
  toggle,
}

class HotkeyShortcut {
  const HotkeyShortcut({
    required this.keyCode,
    this.modifiers = const {},
    this.label,
  });

  final int keyCode;
  final Set<HotkeyModifier> modifiers;
  final String? label;
}

enum HotkeyModifier {
  control,
  alt,
  shift,
  meta,
  win,
}

enum HotkeyEventType {
  keyDown,
  keyUp,
}

class HotkeyEvent {
  const HotkeyEvent({
    required this.type,
    required this.keyCode,
    this.modifiers = const {},
  });

  final HotkeyEventType type;
  final int keyCode;
  final Set<HotkeyModifier> modifiers;
}
