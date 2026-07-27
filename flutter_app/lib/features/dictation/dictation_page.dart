import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/shell/shell_navigation.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/fluid_card.dart';
import '../../core/ai/openai_compatible_provider.dart';
import '../../core/models/audio_models.dart';
import '../../core/models/dictation_mode.dart';
import '../../core/models/hotkey_models.dart';
import '../../core/models/desktop_models.dart';
import '../../core/models/transcript_models.dart';
import '../../core/platform/hotkey_vk.dart';
import '../../core/platform/speech_runtime_engine.dart';
import '../../core/platform/wasapi_audio_capture.dart';
import '../../core/platform/whisper_model_store.dart';
import '../../core/platform/win32_credentials_store.dart';
import '../../core/platform/win32_hotkey_source.dart';
import '../../core/platform/win32_overlay_host.dart';
import '../../core/platform/win32_text_injector.dart';
import '../../core/platform/win32_tray_host.dart';
import '../../core/platform/window_chrome_channel.dart';
import '../../core/services/history_manager.dart';
import '../../core/services/hotkey_state_machine.dart';
import '../../core/services/local_api_server.dart';
import '../../core/services/settings_manager.dart';
import '../../core/storage/json_history_store.dart';
import '../../core/storage/json_settings_store.dart';

/// Dictation shell: PTT hotkey → WASAPI → speech_runtime (Whisper / Parakeet).
class DictationPage extends StatefulWidget {
  const DictationPage({super.key});

  @override
  State<DictationPage> createState() => DictationPageState();
}

class DictationPageState extends State<DictationPage> {
  final _hotkeys = Win32HotkeySource();
  final _capture = WasapiAudioCapture();
  final _speech = SpeechRuntimeEngine();
  final _injector = Win32TextInjector();
  final _overlay = Win32OverlayHost();
  final _tray = Win32TrayHost();
  final _settings = SettingsManager(JsonSettingsStore());
  final _history = HistoryManager(JsonHistoryStore());
  final _credentials = Win32CredentialsStore();
  final _windowChrome = WindowChromeChannel();
  LocalApiServer? _localApi;
  late final HotkeyStateMachine _machine;
  String _hotkeyLabel = 'F8';

  final List<StreamSubscription<dynamic>> _subs = [];
  final List<double> _pcm = [];

  String _status = 'Starting…';
  String _detail = '';
  String _transcript = '';
  bool _recording = false;
  bool _busy = false;
  int _audioChunks = 0;
  /// Bumped on stop so an in-flight start cannot leave the mic open.
  int _recordGeneration = 0;
  String _activeModelId = WhisperModelStore.defaultModelId;

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
      await _history.load(retentionDays: _settings.historyRetentionDays);
      await _applyWindowChrome();

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

      // Shortcut must be configured before start().
      await _applySettings(showModelDownload: true, startHotkeys: true);

      if (!mounted) return;
      _setReadyStatus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Startup failed';
        _detail = e.toString();
      });
    }
  }

  Future<void> _applySettings({
    bool showModelDownload = false,
    bool startHotkeys = false,
  }) async {
    await _settings.load();

    if (_settings.hotkeyShortcut == null) {
      _settings.hotkeyShortcut = kDefaultHotkeyShortcut;
      await _settings.save();
    }
    final shortcut = _settings.hotkeyShortcut!;
    _machine.setMode(_settings.hotkeyMode);
    _machine.setShortcut(shortcut);
    await _hotkeys.setShortcut(shortcut);
    _hotkeyLabel = formatHotkeyShortcut(shortcut);
    await _applyWindowChrome();
    if (startHotkeys) {
      await _hotkeys.start();
    }

    if (_settings.selectedMicId != null &&
        _settings.selectedMicId!.isNotEmpty &&
        _capture.isNativeAvailable) {
      await _capture.setDevice(_settings.selectedMicId!);
    }

    final modelId =
        _settings.selectedModelId ?? WhisperModelStore.defaultModelId;
    _activeModelId = modelId;
    if (_speech.isNativeAvailable) {
      if (showModelDownload && mounted) {
        setState(() {
          _status = 'Loading $modelId…';
          _detail = modelId.startsWith('parakeet')
              ? 'Parakeet ONNX — first load can take a minute'
              : 'Whisper ggml — downloading if needed';
        });
      }
      await _speech.prepare(modelId: modelId);
      _activeModelId = _speech.readyModelId ?? modelId;
    }

    if (_settings.localApiEnabled) {
      if (_localApi == null) {
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
    } else if (_localApi != null) {
      await _localApi!.stop();
      _localApi = null;
    }

    if (mounted) {
      _setReadyStatus();
    }
  }

  Future<void> _applyWindowChrome() async {
    try {
      await _windowChrome.setAlwaysOnTop(_settings.alwaysOnTop);
      await _windowChrome.setAcrylic(_settings.acrylicEnabled);
    } catch (_) {}
  }

  void _setReadyStatus() {
    final model = _speech.readyModelId ?? _activeModelId;
    final backend = model.startsWith('parakeet') ? 'Parakeet ONNX' : 'Whisper';
    setState(() {
      _status = 'Ready — hold $_hotkeyLabel to dictate';
      _detail = [
        'model:$model',
        'backend:$backend',
        if (_capture.isNativeAvailable) 'WASAPI',
        'hotkeys',
        if (_injector.isNativeAvailable) 'inject',
        'tray',
        if (_localApi != null) 'api:${LocalApiServer.defaultPort}',
        if (_settings.outputMode != DictationOutputMode.raw)
          'mode:${_settings.outputMode.name}',
        if (_settings.pauseMediaWhileDictating) 'media-pause',
      ].join(' · ');
    });
  }

  Future<void> reloadAfterExternalEdit({bool showModelDownload = false}) async {
    if (!mounted) return;
    await _applySettings(showModelDownload: showModelDownload);
  }

  void _openSettings() {
    ShellNavigation.maybeOf(context)?.goTo(ShellPage.settings);
  }

  Future<void> _onTrayAction(TrayAction action) async {
    switch (action.id) {
      case 'show':
        await _tray.showApp();
      case 'settings':
        await _tray.showApp();
        if (!mounted) return;
        _openSettings();
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
        final gen = ++_recordGeneration;
        _pcm.clear();
        setState(() {
          _recording = true;
          _status = 'Listening — hold $_hotkeyLabel';
          _detail = 'model:$_activeModelId';
          _audioChunks = 0;
          _transcript = '';
        });
        try {
          await _tray.setStatus(AppTrayStatus.listening);
          await _overlay.setTranscript('');
          await _overlay.setClickThrough(true);
          await _overlay.show();
        } catch (_) {}
        if (gen != _recordGeneration) return;
        if (_settings.pauseMediaWhileDictating) {
          try {
            await _injector.mediaPlayPause();
          } catch (_) {}
        }
        if (gen != _recordGeneration) return;
        if (_capture.isNativeAvailable) {
          try {
            await _capture.start();
          } catch (e) {
            if (!mounted) return;
            setState(() => _detail = 'Mic start failed: $e');
          }
        }
        // Tap was so short stop already ran — do not leave the mic open.
        if (gen != _recordGeneration && _capture.isNativeAvailable) {
          try {
            await _capture.stop();
          } catch (_) {}
        }
      case HotkeyMachineAction.stopRecording:
        // Invalidate any in-flight start before awaiting I/O.
        _recordGeneration++;
        if (_capture.isNativeAvailable) {
          try {
            await _capture.stop();
          } catch (_) {}
        }
        if (_settings.pauseMediaWhileDictating) {
          try {
            await _injector.mediaPlayPause();
          } catch (_) {}
        }
        if (!mounted) return;
        setState(() {
          _recording = false;
          _busy = true;
          _status = 'Transcribing…';
          _detail = '$_activeModelId · ${_pcm.length} samples @ 16 kHz';
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

      // Reload selection in case Models page changed it while we were open.
      await _settings.load();
      final modelId =
          _settings.selectedModelId ?? WhisperModelStore.defaultModelId;
      _activeModelId = modelId;
      if (_speech.readyModelId != modelId) {
        if (mounted) {
          setState(() {
            _status = 'Loading $modelId…';
            _detail = modelId.startsWith('parakeet')
                ? 'Parakeet ONNX — first load can take a minute'
                : 'Switching Whisper model…';
          });
        }
        await _speech.prepare(modelId: modelId);
        _activeModelId = _speech.readyModelId ?? modelId;
      }

      if (mounted) {
        setState(() {
          _status = 'Transcribing ($_activeModelId)…';
          _detail = _activeModelId.startsWith('parakeet')
              ? 'Parakeet ONNX'
              : 'Whisper ggml';
        });
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
            retentionDays: _settings.historyRetentionDays,
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

  String get _phaseLabel {
    if (_status.toLowerCase().contains('fail') ||
        _status.toLowerCase().contains('missing')) {
      return 'Error';
    }
    if (_recording) return 'Listening';
    if (_busy) return 'Working';
    if (_status.startsWith('Ready')) return 'Ready';
    return 'Starting';
  }

  Color get _phaseColor {
    switch (_phaseLabel) {
      case 'Listening':
        return FluidColors.danger;
      case 'Working':
        return FluidColors.warning;
      case 'Error':
        return FluidColors.danger;
      case 'Ready':
        return FluidColors.accent;
      default:
        return FluidColors.secondaryText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isError = _phaseLabel == 'Error';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FluidSpacing.xxl,
        FluidSpacing.xxl,
        FluidSpacing.xxl,
        FluidSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Home', style: theme.textTheme.titleLarge),
                    const SizedBox(height: FluidSpacing.sm),
                    Text(
                      isError
                          ? _status
                          : (_recording
                              ? 'Listening — release $_hotkeyLabel to finish'
                              : 'Hold $_hotkeyLabel to dictate'),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: isError
                            ? FluidColors.danger
                            : FluidColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(label: _phaseLabel, color: _phaseColor),
            ],
          ),
          if (_detail.isNotEmpty) ...[
            const SizedBox(height: FluidSpacing.lg),
            Text(
              _detail,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isError
                    ? FluidColors.danger
                    : FluidColors.tertiaryText,
              ),
            ),
          ],
          const SizedBox(height: FluidSpacing.xxl),
          Row(
            children: [
              Text('Transcript', style: theme.textTheme.titleMedium),
              const Spacer(),
              if (_audioChunks > 0)
                Text(
                  '$_audioChunks chunks',
                  style: theme.textTheme.labelSmall,
                ),
            ],
          ),
          const SizedBox(height: FluidSpacing.md),
          Expanded(
            child: FluidCard(
              elevated: true,
              padding: const EdgeInsets.all(FluidSpacing.xl),
              child: SingleChildScrollView(
                child: SelectableText(
                  _transcript.isEmpty
                      ? 'Your latest transcript will show up here.'
                      : _transcript,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: _transcript.isEmpty
                        ? FluidColors.tertiaryText
                        : FluidColors.primaryText,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FluidSpacing.md,
        vertical: FluidSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(FluidRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: FluidSpacing.sm),
          Text(
            label,
            style: fluidText(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
