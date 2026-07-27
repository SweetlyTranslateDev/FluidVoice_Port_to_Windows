import 'package:flutter/foundation.dart';

/// Visual phase for the floating dictation pill.
enum DictationHudPhase {
  idle,
  listening,
  processing,
  error,
}

/// Shared HUD state for the native always-on-top pill + transcript window.
class DictationHudController extends ChangeNotifier {
  DictationHudController._();
  static final instance = DictationHudController._();

  DictationHudPhase _phase = DictationHudPhase.idle;
  double _amplitude = 0;
  String _transcript = '';
  bool _enabled = false;

  DictationHudPhase get phase => _phase;
  double get amplitude => _amplitude;
  String get transcript => _transcript;
  bool get enabled => _enabled;

  void setEnabled(bool enabled) {
    if (_enabled == enabled) return;
    _enabled = enabled;
    notifyListeners();
  }

  void setPhase(DictationHudPhase phase) {
    if (_phase == phase) return;
    _phase = phase;
    if (phase != DictationHudPhase.listening) {
      _amplitude = 0;
    }
    notifyListeners();
  }

  void setAmplitude(double value) {
    final next = value.clamp(0.0, 1.0);
    if ((next - _amplitude).abs() < 0.008) return;
    _amplitude = next;
    notifyListeners();
  }

  void setTranscript(String text) {
    if (_transcript == text) return;
    _transcript = text;
    notifyListeners();
  }
}
