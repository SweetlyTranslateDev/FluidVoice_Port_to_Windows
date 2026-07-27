import '../models/dictation_mode.dart';
import '../models/hotkey_models.dart';
import '../platform/hotkey_vk.dart';
import '../platform/win32_hotkey_source.dart';
import '../storage/settings_store.dart';

/// How long transcript history is retained. `0` means keep forever.
class HistoryRetention {
  static const forever = 0;
  static const options = <int>[1, 7, 30, 90, 365, forever];

  static String label(int days) {
    if (days <= 0) return 'Forever';
    if (days == 1) return '1 day';
    return '$days days';
  }
}

/// Application settings. Persistence is Dart-side; OS bridges use MethodChannels.
class SettingsManager {
  SettingsManager(this._store);

  final SettingsStore _store;

  HotkeyActivationMode hotkeyMode = HotkeyActivationMode.pushToTalk;
  HotkeyShortcut? hotkeyShortcut;
  String? selectedModelId;
  String? selectedMicId;
  bool aiEnhancementEnabled = false;
  DictationOutputMode outputMode = DictationOutputMode.raw;
  String? aiBaseUrl;
  bool localApiEnabled = false;
  bool pauseMediaWhileDictating = false;
  int historyRetentionDays = 30;
  bool sidebarCollapsed = false;
  bool alwaysOnTop = false;
  bool acrylicEnabled = true;
  /// Floating WaveVisualizer pill + transcript (off by default).
  bool floatingPillEnabled = false;
  /// When true, minimize hides to the system tray; when false, normal taskbar minimize.
  bool minimizeToTray = false;

  Future<void> load() async {
    final data = await _store.readAll();
    hotkeyMode = HotkeyActivationMode.values.firstWhere(
      (m) => m.name == data['hotkeyMode'],
      orElse: () => HotkeyActivationMode.pushToTalk,
    );
    selectedModelId = data['selectedModelId'];
    if (selectedModelId != null && selectedModelId!.trim().isEmpty) {
      selectedModelId = null;
    }
    selectedMicId = data['selectedMicId'];
    if (selectedMicId != null && selectedMicId!.trim().isEmpty) {
      selectedMicId = null;
    }
    aiEnhancementEnabled = data['aiEnhancementEnabled'] == 'true';
    aiBaseUrl = data['aiBaseUrl'];
    localApiEnabled = data['localApiEnabled'] == 'true';
    pauseMediaWhileDictating = data['pauseMediaWhileDictating'] == 'true';
    sidebarCollapsed = data['sidebarCollapsed'] == 'true';
    alwaysOnTop = data['alwaysOnTop'] == 'true';
    acrylicEnabled = data['acrylicEnabled'] != 'false';
    floatingPillEnabled = data['floatingPillEnabled'] == 'true';
    minimizeToTray = data['minimizeToTray'] == 'true';
    historyRetentionDays = int.tryParse(data['historyRetentionDays'] ?? '') ??
        30;
    if (!HistoryRetention.options.contains(historyRetentionDays) &&
        historyRetentionDays != HistoryRetention.forever) {
      historyRetentionDays = 30;
    }

    outputMode = DictationOutputMode.values.firstWhere(
      (m) => m.name == data['outputMode'],
      orElse: () => aiEnhancementEnabled
          ? DictationOutputMode.enhance
          : DictationOutputMode.raw,
    );

    final keyCode = int.tryParse(data['hotkeyKeyCode'] ?? '');
    if (keyCode != null) {
      final mods = decodeHotkeyModifiers(
        int.tryParse(data['hotkeyModifiers'] ?? '') ?? 0,
      );
      final shortcut = HotkeyShortcut(
        keyCode: keyCode,
        modifiers: mods,
        label: data['hotkeyLabel'],
      );
      hotkeyShortcut = HotkeyShortcut(
        keyCode: shortcut.keyCode,
        modifiers: shortcut.modifiers,
        label: formatHotkeyShortcut(shortcut),
      );
    } else {
      hotkeyShortcut = kDefaultHotkeyShortcut;
    }
  }

  Future<void> save() async {
    aiEnhancementEnabled = outputMode != DictationOutputMode.raw;
    final shortcut = hotkeyShortcut;
    await _store.writeAll({
      'hotkeyMode': hotkeyMode.name,
      'selectedModelId': selectedModelId ?? '',
      'selectedMicId': selectedMicId ?? '',
      'aiEnhancementEnabled': aiEnhancementEnabled.toString(),
      'outputMode': outputMode.name,
      'aiBaseUrl': aiBaseUrl ?? '',
      'localApiEnabled': localApiEnabled.toString(),
      'pauseMediaWhileDictating': pauseMediaWhileDictating.toString(),
      'historyRetentionDays': historyRetentionDays.toString(),
      'sidebarCollapsed': sidebarCollapsed.toString(),
      'alwaysOnTop': alwaysOnTop.toString(),
      'acrylicEnabled': acrylicEnabled.toString(),
      'floatingPillEnabled': floatingPillEnabled.toString(),
      'minimizeToTray': minimizeToTray.toString(),
      'hotkeyKeyCode': shortcut?.keyCode.toString() ?? '',
      'hotkeyModifiers':
          encodeHotkeyModifiers(shortcut?.modifiers ?? {}).toString(),
      'hotkeyLabel': shortcut == null ? '' : formatHotkeyShortcut(shortcut),
    });
  }
}
