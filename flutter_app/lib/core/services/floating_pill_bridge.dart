import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';

import '../platform/win32_tray_host.dart';
import '../storage/json_settings_store.dart';
import 'dictation_hud_controller.dart';
import 'settings_manager.dart';

/// Opens a separate Flutter window with WaveVisualizer and keeps it in sync.
class FloatingPillBridge {
  FloatingPillBridge({
    DictationHudController? controller,
    Win32TrayHost? tray,
  })  : _hud = controller ?? DictationHudController.instance,
        _tray = tray ?? Win32TrayHost();

  final DictationHudController _hud;
  final Win32TrayHost _tray;
  final _settings = SettingsManager(JsonSettingsStore());
  WindowController? _pill;
  WindowController? _main;
  bool _started = false;
  bool _opening = false;
  DictationHudPhase? _lastPhase;
  String? _lastTranscript;
  double _lastAmplitude = -1;

  static const _pillArg = 'pill';

  void start() {
    if (_started) return;
    _started = true;
    _hud.addListener(_onHud);
    unawaited(_bindMainHandler());
    unawaited(_sync());
  }

  void dispose() {
    if (!_started) return;
    _started = false;
    _hud.removeListener(_onHud);
  }

  void _onHud() => unawaited(_sync());

  Future<void> _bindMainHandler() async {
    try {
      _main = await WindowController.fromCurrentEngine();
      await _main!.setWindowMethodHandler((call) async {
        if (call.method == 'restoreFromPill') {
          await restoreMainFromPill();
          return null;
        }
        throw MissingPluginException(call.method);
      });
    } catch (_) {}
  }

  /// Close the pill, turn the setting off, and show the main window.
  Future<void> restoreMainFromPill() async {
    _hud.setEnabled(false);
    try {
      await _settings.load();
      _settings.floatingPillEnabled = false;
      await _settings.save();
    } catch (_) {}
    try {
      await _pill?.hide();
    } catch (_) {}
    try {
      await _tray.showApp();
    } catch (_) {}
    _lastPhase = null;
    _lastTranscript = null;
    _lastAmplitude = -1;
  }

  String _phaseName(DictationHudPhase phase) {
    switch (phase) {
      case DictationHudPhase.listening:
        return 'listening';
      case DictationHudPhase.processing:
        return 'processing';
      case DictationHudPhase.error:
        return 'error';
      case DictationHudPhase.idle:
        return 'idle';
    }
  }

  Future<WindowController> _ensurePillWindow() async {
    final existing = _pill;
    if (existing != null) return existing;

    if (_opening) {
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        if (_pill != null) return _pill!;
      }
    }

    _opening = true;
    try {
      final all = await WindowController.getAll();
      for (final c in all) {
        if (c.arguments == _pillArg) {
          _pill = c;
          return c;
        }
      }
      final created = await WindowController.create(
        const WindowConfiguration(
          arguments: _pillArg,
          hiddenAtLaunch: true,
        ),
      );
      _pill = created;
      return created;
    } finally {
      _opening = false;
    }
  }

  Future<void> _pushHud(WindowController pill) async {
    final phase = _hud.phase;
    final transcript = _hud.transcript;
    final amp = _hud.amplitude;
    final phaseChanged = _lastPhase != phase;
    final textChanged = _lastTranscript != transcript;
    final ampChanged = (amp - _lastAmplitude).abs() >= 0.015;
    if (!phaseChanged && !textChanged && !ampChanged) return;

    _lastPhase = phase;
    _lastTranscript = transcript;
    _lastAmplitude = amp;

    await pill.invokeMethod<void>('hudUpdate', <String, dynamic>{
      'phase': _phaseName(phase),
      'amplitude': amp,
      'transcript': transcript,
    });
  }

  Future<void> _sync() async {
    try {
      if (!_hud.enabled) {
        final pill = _pill;
        if (pill != null) {
          await pill.hide();
        }
        _lastPhase = null;
        _lastTranscript = null;
        _lastAmplitude = -1;
        return;
      }

      final pill = await _ensurePillWindow();
      await pill.show();
      for (var i = 0; i < 8; i++) {
        try {
          await _pushHud(pill);
          break;
        } catch (_) {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          _lastPhase = null;
          _lastTranscript = null;
          _lastAmplitude = -1;
        }
      }
    } catch (_) {}
  }
}
