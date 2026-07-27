import 'dart:async';

import '../models/hotkey_models.dart';

enum HotkeyMachineAction {
  startRecording,
  stopRecording,
  toggleRecording,
}

/// Pure Dart hotkey semantics. Native layer only emits [HotkeyEvent]s.
class HotkeyStateMachine {
  HotkeyStateMachine({
    HotkeyActivationMode mode = HotkeyActivationMode.pushToTalk,
    HotkeyShortcut? shortcut,
  })  : _mode = mode,
        _shortcut = shortcut;

  HotkeyActivationMode _mode;
  HotkeyShortcut? _shortcut;
  bool _recording = false;
  bool _keyDown = false;

  final _actions = StreamController<HotkeyMachineAction>.broadcast();

  Stream<HotkeyMachineAction> get actions => _actions.stream;

  HotkeyActivationMode get mode => _mode;
  bool get isRecording => _recording;

  void setMode(HotkeyActivationMode mode) {
    _mode = mode;
  }

  void setShortcut(HotkeyShortcut shortcut) {
    _shortcut = shortcut;
  }

  void handle(HotkeyEvent event) {
    final shortcut = _shortcut;
    if (shortcut == null) return;
    if (event.keyCode != shortcut.keyCode) return;

    switch (_mode) {
      case HotkeyActivationMode.pushToTalk:
        if (event.type == HotkeyEventType.keyDown) {
          // Exact modifiers required to start.
          if (!_modifiersMatch(event.modifiers, shortcut.modifiers)) return;
          if (_keyDown) return;
          _keyDown = true;
          if (!_recording) {
            _recording = true;
            _actions.add(HotkeyMachineAction.startRecording);
          }
        } else if (event.type == HotkeyEventType.keyUp) {
          // Accept key-up even if modifiers were released first (native emits
          // this case). Otherwise PTT never stops for Ctrl/Alt/Shift combos.
          if (!_keyDown) return;
          _keyDown = false;
          if (_recording) {
            _recording = false;
            _actions.add(HotkeyMachineAction.stopRecording);
          }
        }
      case HotkeyActivationMode.toggle:
        if (event.type == HotkeyEventType.keyDown) {
          if (!_modifiersMatch(event.modifiers, shortcut.modifiers)) return;
          if (_keyDown) return;
          _keyDown = true;
          _recording = !_recording;
          _actions.add(
            _recording
                ? HotkeyMachineAction.startRecording
                : HotkeyMachineAction.stopRecording,
          );
        } else if (event.type == HotkeyEventType.keyUp) {
          _keyDown = false;
        }
    }
  }

  bool _modifiersMatch(Set<HotkeyModifier> actual, Set<HotkeyModifier> required) {
    bool held(HotkeyModifier m) {
      if (m == HotkeyModifier.meta || m == HotkeyModifier.win) {
        return actual.contains(HotkeyModifier.meta) ||
            actual.contains(HotkeyModifier.win);
      }
      return actual.contains(m);
    }

    bool wanted(HotkeyModifier m) {
      if (m == HotkeyModifier.meta || m == HotkeyModifier.win) {
        return required.contains(HotkeyModifier.meta) ||
            required.contains(HotkeyModifier.win);
      }
      return required.contains(m);
    }

    // Exact match on ctrl/alt/shift/win so Ctrl+F8 ≠ bare F8.
    for (final m in const [
      HotkeyModifier.control,
      HotkeyModifier.alt,
      HotkeyModifier.shift,
      HotkeyModifier.win,
    ]) {
      if (held(m) != wanted(m)) return false;
    }
    return true;
  }

  Future<void> dispose() async {
    await _actions.close();
  }
}
