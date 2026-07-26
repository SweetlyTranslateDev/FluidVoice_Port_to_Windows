import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';
import '../../core/ai/openai_compatible_provider.dart';
import '../../core/models/audio_models.dart';
import '../../core/models/dictation_mode.dart';
import '../../core/models/hotkey_models.dart';
import '../../core/models/desktop_models.dart';
import '../../core/models/transcript_models.dart';
import '../../core/platform/speech_runtime_engine.dart';
import '../../core/platform/wasapi_audio_capture.dart';
import '../../core/platform/whisper_model_store.dart';
import '../../core/platform/win32_credentials_store.dart';
import '../../core/platform/win32_hotkey_source.dart';
import '../../core/platform/win32_overlay_host.dart';
import '../../core/platform/win32_text_injector.dart';
import '../../core/platform/win32_tray_host.dart';
import '../../core/services/history_manager.dart';
import '../../core/services/hotkey_state_machine.dart';
import '../../core/services/local_api_server.dart';
import '../../core/services/settings_manager.dart';
import '../../core/storage/json_history_store.dart';
import '../../core/storage/json_settings_store.dart';

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
  final _tray = Win32TrayHost();
  final _settings = SettingsManager(JsonSettingsStore());
  final _history = HistoryManager(JsonHistoryStore());
  final _credentials = Win32CredentialsStore();
  LocalApiServer? _localApi;
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

      await _settings.load();
      await _history.load();
      if (_settings.selectedMicId != null &&
          _settings.selectedMicId!.isNotEmpty) {
        await _capture.setDevice(_settings.selectedMicId!);
      }

      _subs.add(_hotkeys.events.listen(_machine.handle));
      _subs.add(_machine.actions.listen(_onAction));
      _subs.add(_capture.audioStream.listen((chunk) {
        _pcm.addAll(chunk.samples);
        if (!mounted) return;
        setState(() => _audioChunks += 1);
      }));
      _subs.add(_tray.actions.listen(_onTrayAction));

      try {
        await _tray.start();
      } catch (_) {}

      await _hotkeys.setShortcut(
        _settings.hotkeyShortcut ?? kDefaultHotkeyShortcut,
      );
      await _hotkeys.start();

      final modelId =
          _settings.selectedModelId ?? WhisperModelStore.defaultModelId;
      if (_speech.isNativeAvailable) {
        setState(() {
          _status = 'Downloading Whisper model…';
          _detail = '$modelId (cached after first run)';
        });
        await _speech.prepare(modelId: modelId);
      }

      if (_settings.localApiEnabled) {
        _localApi = LocalApiServer(
          settings: _settings,
          history: _history,
          speechEngine: _speech.isNativeAvailable ? _speech : null,
        );
        try {
          await _localApi!.start();
        } catch (_) {
          _localApi = null;
        }
      }

      if (!mounted) return;
      setState(() {
        _status = 'Ready — hold F8 to dictate';
        _detail = [
          if (_capture.isNativeAvailable) 'WASAPI',
          'hotkeys',
          if (_speech.isNativeAvailable) 'whisper',
          if (_injector.isNativeAvailable) 'inject',
          'tray',
          if (_localApi != null) 'api:${LocalApiServer.defaultPort}',
          if (_settings.outputMode != DictationOutputMode.raw)
            'mode:${_settings.outputMode.name}',
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

  Future<void> _onTrayAction(TrayAction action) async {
    switch (action.id) {
      case 'show':
        await _tray.showApp();
      case 'settings':
        await _tray.showApp();
        if (!mounted) return;
        await Navigator.of(context).pushNamed(AppRoutes.settings);
      case 'quit':
        await _tray.quitApp();
      default:
        break;
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
          await _tray.setStatus(AppTrayStatus.listening);
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
          await _tray.setStatus(AppTrayStatus.processing);
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
          await _tray.setStatus(AppTrayStatus.idle);
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
          await _tray.setStatus(AppTrayStatus.idle);
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

      var text = result.text;
      var injectDetail = text.isEmpty
          ? 'No speech detected'
          : 'Transcription complete';

      if (text.isNotEmpty &&
          _settings.outputMode != DictationOutputMode.raw) {
        try {
          setState(() {
            _status = 'AI ${_settings.outputMode.name}…';
          });
          text = await _runAiMode(text);
          injectDetail = 'AI ${_settings.outputMode.name} complete';
        } catch (e) {
          injectDetail = 'AI failed, using raw text: $e';
          text = result.text;
        }
      }

      if (text.isNotEmpty && _injector.isNativeAvailable) {
        try {
          await _injector.insertText(text);
          injectDetail = 'Inserted into focused app';
        } catch (e) {
          injectDetail = 'Transcribed; insert failed: $e';
        }
      }

      if (text.isNotEmpty) {
        try {
          await _history.addFromResult(
            TranscriptResult(text: text, rawText: result.text),
          );
        } catch (_) {}
      }

      try {
        if (text.isNotEmpty) {
          await _overlay.setTranscript(text);
        }
        await Future<void>.delayed(const Duration(milliseconds: 900));
        await _overlay.hide();
      } catch (_) {}

      try {
        await _tray.setStatus(AppTrayStatus.idle);
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _busy = false;
        _transcript = text;
        _status = 'Ready — hold F8 to dictate';
        _detail = injectDetail;
      });
    } catch (e) {
      try {
        await _overlay.hide();
        await _tray.setStatus(AppTrayStatus.error);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Ready — hold F8 to dictate';
        _detail = 'Transcribe failed: $e';
      });
      try {
        await _tray.setStatus(AppTrayStatus.idle);
      } catch (_) {}
    }
  }

  Future<String> _runAiMode(String transcript) async {
    final key = await _credentials.readSecret(Win32CredentialsStore.aiApiKey);
    if (key == null || key.isEmpty) {
      throw StateError('Configure an AI API key in Settings');
    }
    final base = (_settings.aiBaseUrl == null || _settings.aiBaseUrl!.isEmpty)
        ? 'https://api.openai.com/v1'
        : _settings.aiBaseUrl!;
    final ai = OpenAiCompatibleProvider(baseUrl: base, apiKey: key);
    return switch (_settings.outputMode) {
      DictationOutputMode.rewrite => ai.rewrite(transcript: transcript),
      DictationOutputMode.write => ai.write(transcript: transcript),
      DictationOutputMode.enhance => ai.enhance(transcript: transcript),
      DictationOutputMode.raw => transcript,
    };
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    unawaited(_localApi?.stop() ?? Future<void>.value());
    unawaited(_capture.dispose());
    unawaited(_hotkeys.dispose());
    unawaited(_speech.dispose());
    unawaited(_tray.dispose());
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
