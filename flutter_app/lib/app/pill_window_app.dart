import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import 'theme/app_theme.dart';
import 'widgets/floating_dictation_hud.dart';
import '../core/services/dictation_hud_controller.dart';

/// Separate always-on-top Flutter window hosting the WaveVisualizer pill.
class PillWindowApp extends StatefulWidget {
  const PillWindowApp({super.key, required this.controller});

  final WindowController controller;

  @override
  State<PillWindowApp> createState() => _PillWindowAppState();
}

class _PillWindowAppState extends State<PillWindowApp> with WindowListener {
  DictationHudPhase _phase = DictationHudPhase.idle;
  double _amplitude = 0;
  String _transcript = '';

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    unawaited(_configureWindow());
    unawaited(
      widget.controller.setWindowMethodHandler((call) async {
        if (call.method == 'hudUpdate') {
          final args = call.arguments;
          if (args is Map) {
            final phase = args['phase']?.toString() ?? 'idle';
            final amp = (args['amplitude'] as num?)?.toDouble() ?? 0;
            final text = args['transcript']?.toString() ?? '';
            if (!mounted) return null;
            setState(() {
              _phase = _parsePhase(phase);
              _amplitude = amp.clamp(0.0, 1.0);
              _transcript = text;
            });
          }
          return null;
        }
        throw MissingPluginException(call.method);
      }),
    );
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  DictationHudPhase _parsePhase(String phase) {
    switch (phase) {
      case 'listening':
        return DictationHudPhase.listening;
      case 'processing':
        return DictationHudPhase.processing;
      case 'error':
        return DictationHudPhase.error;
      default:
        return DictationHudPhase.idle;
    }
  }

  Future<void> _configureWindow() async {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(340, 240),
      center: false,
      backgroundColor: Colors.transparent,
      skipTaskbar: true,
      titleBarStyle: TitleBarStyle.hidden,
      alwaysOnTop: true,
      windowButtonVisibility: false,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setAsFrameless();
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSkipTaskbar(true);
      await windowManager.setResizable(false);
      await windowManager.setPosition(const Offset(48, 48));
      await windowManager.show();
    });
  }

  Future<void> _requestRestoreMain() async {
    try {
      final windows = await WindowController.getAll();
      for (final c in windows) {
        if (c.arguments != 'pill') {
          await c.invokeMethod<void>('restoreFromPill');
          break;
        }
      }
    } catch (_) {}
    try {
      await windowManager.hide();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildFluidVoiceTheme(),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Align(
          alignment: Alignment.topCenter,
          child: FloatingDictationHud(
            phase: _phase,
            amplitude: _amplitude,
            transcript: _transcript,
            onClose: () {
              unawaited(_requestRestoreMain());
            },
          ),
        ),
      ),
    );
  }
}
