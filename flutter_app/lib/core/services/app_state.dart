import 'package:flutter/foundation.dart';

import '../models/desktop_models.dart';
import '../models/hotkey_models.dart';

/// Observable application state owned by Dart core (not C++).
class AppState extends ChangeNotifier {
  DictationSessionState _session = DictationSessionState.idle;
  String _liveTranscript = '';
  String? _lastError;
  HotkeyActivationMode _hotkeyMode = HotkeyActivationMode.pushToTalk;
  String? _selectedModelId;
  String? _selectedMicId;

  DictationSessionState get session => _session;
  String get liveTranscript => _liveTranscript;
  String? get lastError => _lastError;
  HotkeyActivationMode get hotkeyMode => _hotkeyMode;
  String? get selectedModelId => _selectedModelId;
  String? get selectedMicId => _selectedMicId;

  void setSession(DictationSessionState value) {
    if (_session == value) return;
    _session = value;
    notifyListeners();
  }

  void setLiveTranscript(String value) {
    if (_liveTranscript == value) return;
    _liveTranscript = value;
    notifyListeners();
  }

  void setError(String? value) {
    _lastError = value;
    if (value != null) {
      _session = DictationSessionState.error;
    }
    notifyListeners();
  }

  void setHotkeyMode(HotkeyActivationMode mode) {
    if (_hotkeyMode == mode) return;
    _hotkeyMode = mode;
    notifyListeners();
  }

  void setSelectedModelId(String? id) {
    if (_selectedModelId == id) return;
    _selectedModelId = id;
    notifyListeners();
  }

  void setSelectedMicId(String? id) {
    if (_selectedMicId == id) return;
    _selectedMicId = id;
    notifyListeners();
  }
}
