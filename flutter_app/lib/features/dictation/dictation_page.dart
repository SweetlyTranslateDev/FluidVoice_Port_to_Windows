import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';
import '../../core/models/audio_models.dart';
import '../../core/models/hotkey_models.dart';
import '../../core/platform/speech_runtime_engine.dart';
import '../../core/platform/wasapi_audio_capture.dart';
import '../../core/platform/whisper_model_store.dart';
import '../../core/platform/win32_hotkey_source.dart';
import '../../core/platform/win32_overlay_host.dart';
import '../../core/platform/win32_text_injector.dart';
import '../../core/services/hotkey_state_machine.dart';

/// Dictation shell: F8 PTT → WASAPI → speech_runtime (whisper.cpp).
class DictationPage extends StatefulWidget {
  const DictationPage({super.key});

  @override
  State<DictationPage> createState() => _DictationPageState();
}

class _DictationPageState extends State<DictationPage> {
  final _hotkeys = Win32HotkeySource();
  final _capture = WasapiAudioCapture();
  final _speech = SpeechRuntimeEngine();
  final _injector = Win32TextInjector();
  final _overlay = Win32OverlayHost();
  late final HotkeyStateMachine _machine;

  final List<StreamSubscription<dynamic>> _subs = [];
  final List<double> _pcm = [];

  String _status = 'Starting…';
  String _detail = '';
  String _transcript = '';
  bool _recording = false;
  bool _busy = false;
  int _audioChunks = 0;

  @override
  void initState() {
    super.initState();
    _machine = HotkeyStateMachine(
      mode: HotkeyActivationMode.pushToTalk,
      shortcut: kDefaultHotkeyShortcut,
    );
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      if (!_hotkeys.isNativeAvailable) {
        setState(() {
          _status = 'Hotkeys DLL missing';
          _detail =
              'Build with: cd C:\\dev\\FluidVoice_Port_to_Windows\\flutter_app ; flutter run -d windows';
        });
        return;
      }

      _subs.add(_hotkeys.events.listen(_machine.handle));
      _subs.add(_machine.actions.listen(_onAction));
      _subs.add(_capture.audioStream.listen((chunk) {
        _pcm.addAll(chunk.samples);
        if (!mounted) return;
        setState(() => _audioChunks += 1);
      }));

      await _hotkeys.setShortcut(kDefaultHotkeyShortcut);
      await _hotkeys.start();

      if (_speech.isNativeAvailable) {
        setState(() {
          _status = 'Downloading Whisper model…';
          _detail = 'tiny.en (one-time)';
        });
        await _speech.prepare(modelId: WhisperModelStore.defaultModelId);
      }

      if (!mounted) return;
      setState(() {
        _status = 'Ready — hold F8 to dictate';
        _detail = [
          if (_capture.isNativeAvailable) 'WASAPI',
          'hotkeys',
          if (_speech.isNativeAvailable) 'whisper',
          if (_injector.isNativeAvailable) 'inject',
        ].join(' + ');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Startup failed';
        _detail = e.toString();
      });
    }
  }

  Future<void> _onAction(HotkeyMachineAction action) async {
    switch (action) {
      case HotkeyMachineAction.startRecording:
        if (_busy) return;
        _pcm.clear();
        setState(() {
          _recording = true;
          _status = 'Recording (F8 held)';
          _audioChunks = 0;
          _transcript = '';
        });
        try {
          await _overlay.setTranscript('');
          await _overlay.setClickThrough(true);
          await _overlay.show();
        } catch (_) {}
        if (_capture.isNativeAvailable) {
          try {
            await _capture.start();
          } catch (e) {
            if (!mounted) return;
            setState(() => _detail = 'Mic start failed: $e');
          }
        }
      case HotkeyMachineAction.stopRecording:
        if (_capture.isNativeAvailable) {
          await _capture.stop();
        }
        if (!mounted) return;
        setState(() {
          _recording = false;
          _busy = true;
          _status = 'Transcribing…';
          _detail = '${_pcm.length} samples @ 16 kHz';
        });
        try {
          await _overlay.setTranscript('Transcribing…');
        } catch (_) {}
        await _finishTranscription();
      case HotkeyMachineAction.toggleRecording:
        break;
    }
  }

  Future<void> _finishTranscription() async {
    try {
      if (!_speech.isNativeAvailable) {
        try {
          await _overlay.hide();
        } catch (_) {}
        setState(() {
          _busy = false;
          _status = 'Ready — hold F8 to dictate';
          _detail = 'Speech DLL missing; captured $_audioChunks chunks';
        });
        return;
      }
      if (_pcm.isEmpty) {
        try {
          await _overlay.hide();
        } catch (_) {}
        setState(() {
          _busy = false;
          _status = 'Ready — hold F8 to dictate';
          _detail = 'No audio captured';
        });
        return;
      }

      final result = await _speech.transcribe(
        AudioBuffer(samples: List<double>.from(_pcm), sampleRate: 16000, channels: 1),
      );
      _pcm.clear();

      var injectDetail = result.text.isEmpty
          ? 'No speech detected'
          : 'Transcription complete';
      if (result.text.isNotEmpty && _injector.isNativeAvailable) {
        try {
          await _injector.insertText(result.text);
          injectDetail = 'Inserted into focused app';
        } catch (e) {
          injectDetail = 'Transcribed; insert failed: $e';
        }
      }

      try {
        if (result.text.isNotEmpty) {
          await _overlay.setTranscript(result.text);
        }
        await Future<void>.delayed(const Duration(milliseconds: 900));
        await _overlay.hide();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _busy = false;
        _transcript = result.text;
        _status = 'Ready — hold F8 to dictate';
        _detail = injectDetail;
      });
    } catch (e) {
      try {
        await _overlay.hide();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Ready — hold F8 to dictate';
        _detail = 'Transcribe failed: $e';
      });
    }
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    unawaited(_capture.dispose());
    unawaited(_hotkeys.dispose());
    unawaited(_speech.dispose());
    unawaited(_machine.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _recording
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FluidVoice'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'History',
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.history),
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _status,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            Text(_detail),
            const SizedBox(height: 24),
            Text(
              _recording
                  ? 'Listening…'
                  : (_busy ? 'Working…' : 'Idle'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Audio chunks this take: $_audioChunks'),
            const SizedBox(height: 24),
            Text(
              'Transcript',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    _transcript.isEmpty ? '—' : _transcript,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
