import '../models/hotkey_models.dart';
import '../storage/settings_store.dart';

/// Application settings. Persistence is Dart-side; OS bridges use MethodChannels.
class SettingsManager {
  SettingsManager(this._store);

  final SettingsStore _store;

  HotkeyActivationMode hotkeyMode = HotkeyActivationMode.pushToTalk;
  HotkeyShortcut? hotkeyShortcut;
  String? selectedModelId;
  String? selectedMicId;
  bool aiEnhancementEnabled = false;
  String? aiBaseUrl;

  Future<void> load() async {
    final data = await _store.readAll();
    hotkeyMode = HotkeyActivationMode.values.firstWhere(
      (m) => m.name == data['hotkeyMode'],
      orElse: () => HotkeyActivationMode.pushToTalk,
    );
    selectedModelId = data['selectedModelId'];
    selectedMicId = data['selectedMicId'];
    aiEnhancementEnabled = data['aiEnhancementEnabled'] == 'true';
    aiBaseUrl = data['aiBaseUrl'];

    final keyCode = int.tryParse(data['hotkeyKeyCode'] ?? '');
    if (keyCode != null) {
      hotkeyShortcut = HotkeyShortcut(keyCode: keyCode, label: data['hotkeyLabel']);
    }
  }

  Future<void> save() async {
    await _store.writeAll({
      'hotkeyMode': hotkeyMode.name,
      'selectedModelId': selectedModelId ?? '',
      'selectedMicId': selectedMicId ?? '',
      'aiEnhancementEnabled': aiEnhancementEnabled.toString(),
      'aiBaseUrl': aiBaseUrl ?? '',
      'hotkeyKeyCode': hotkeyShortcut?.keyCode.toString() ?? '',
      'hotkeyLabel': hotkeyShortcut?.label ?? '',
    });
  }
}
