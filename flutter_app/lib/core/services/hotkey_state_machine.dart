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
    if (!_modifiersMatch(event.modifiers, shortcut.modifiers)) return;

    switch (_mode) {
      case HotkeyActivationMode.pushToTalk:
        if (event.type == HotkeyEventType.keyDown && !_keyDown) {
          _keyDown = true;
          if (!_recording) {
            _recording = true;
            _actions.add(HotkeyMachineAction.startRecording);
          }
        } else if (event.type == HotkeyEventType.keyUp && _keyDown) {
          _keyDown = false;
          if (_recording) {
            _recording = false;
            _actions.add(HotkeyMachineAction.stopRecording);
          }
        }
      case HotkeyActivationMode.toggle:
        if (event.type == HotkeyEventType.keyDown && !_keyDown) {
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
    return required.every(actual.contains);
  }

  Future<void> dispose() async {
    await _actions.close();
  }
}
