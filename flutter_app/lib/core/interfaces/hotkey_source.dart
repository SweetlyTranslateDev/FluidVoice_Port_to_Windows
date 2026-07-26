import '../models/hotkey_models.dart';

/// Native hotkey event source. State machine stays in Dart.
abstract class HotkeySource {
  Stream<HotkeyEvent> get events;

  Future<void> setShortcut(HotkeyShortcut shortcut);

  Future<void> start();

  Future<void> stop();
}
