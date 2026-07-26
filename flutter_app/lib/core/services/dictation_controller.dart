import 'dart:async';

import '../interfaces/ai_provider.dart';
import '../interfaces/audio_capture.dart';
import '../interfaces/hotkey_source.dart';
import '../interfaces/overlay_host.dart';
import '../interfaces/speech_engine.dart';
import '../interfaces/text_injector.dart';
import '../interfaces/tray_host.dart';
import '../models/audio_models.dart';
import '../models/desktop_models.dart';
import '../models/transcript_models.dart';
import 'app_state.dart';
import 'history_manager.dart';
import 'hotkey_state_machine.dart';
import 'settings_manager.dart';

/// Orchestrates capture → speech → optional AI → inject.
///
/// All business logic stays in Dart. Native plugins only provide HOW.
class DictationController {
  DictationController({
    required this.appState,
    required this.settings,
    required this.history,
    required this.audioCapture,
    required this.speechEngine,
    required this.hotkeySource,
    required this.textInjector,
    required this.overlayHost,
    required this.trayHost,
    this.aiProvider,
  }) : _hotkeyMachine = HotkeyStateMachine(mode: settings.hotkeyMode);

  final AppState appState;
  final SettingsManager settings;
  final HistoryManager history;
  final AudioCapture audioCapture;
  final SpeechEngine speechEngine;
  final HotkeySource hotkeySource;
  final TextInjector textInjector;
  final OverlayHost overlayHost;
  final TrayHost trayHost;
  final AIProvider? aiProvider;

  final HotkeyStateMachine _hotkeyMachine;
  final List<double> _pcm = [];
  final List<StreamSubscription<dynamic>> _subs = [];

  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    await settings.load();
    await history.load();

    _hotkeyMachine.setMode(settings.hotkeyMode);
    if (settings.hotkeyShortcut != null) {
      _hotkeyMachine.setShortcut(settings.hotkeyShortcut!);
      await hotkeySource.setShortcut(settings.hotkeyShortcut!);
    }

    if (settings.selectedModelId != null) {
      appState.setSelectedModelId(settings.selectedModelId);
      await speechEngine.prepare(modelId: settings.selectedModelId!);
    }
    if (settings.selectedMicId != null) {
      appState.setSelectedMicId(settings.selectedMicId);
      await audioCapture.setDevice(settings.selectedMicId!);
    }

    _subs.add(hotkeySource.events.listen(_hotkeyMachine.handle));
    _subs.add(_hotkeyMachine.actions.listen(_onHotkeyAction));
    _subs.add(audioCapture.audioStream.listen(_onAudioChunk));
    _subs.add(speechEngine.transcripts.listen((event) {
      appState.setLiveTranscript(event.text);
      unawaited(overlayHost.setTranscript(event.text));
    }));

    await hotkeySource.start();
    await trayHost.setStatus(AppTrayStatus.idle);
  }

  Future<void> stop() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    await audioCapture.stop();
    await speechEngine.stop();
    await hotkeySource.stop();
    await overlayHost.hide();
    await trayHost.setStatus(AppTrayStatus.idle);
    _started = false;
  }

  Future<void> dispose() async {
    await stop();
    await _hotkeyMachine.dispose();
    await audioCapture.dispose();
    await speechEngine.dispose();
  }

  Future<void> _onHotkeyAction(HotkeyMachineAction action) async {
    switch (action) {
      case HotkeyMachineAction.startRecording:
        await _beginRecording();
      case HotkeyMachineAction.stopRecording:
        await _endRecording();
      case HotkeyMachineAction.toggleRecording:
        if (appState.session == DictationSessionState.recording) {
          await _endRecording();
        } else {
          await _beginRecording();
        }
    }
  }

  Future<void> _beginRecording() async {
    _pcm.clear();
    appState.setError(null);
    appState.setSession(DictationSessionState.recording);
    appState.setLiveTranscript('');
    await trayHost.setStatus(AppTrayStatus.listening);
    await overlayHost.show();
    await speechEngine.start();
    await audioCapture.start();
  }

  Future<void> _endRecording() async {
    await audioCapture.stop();
    appState.setSession(DictationSessionState.transcribing);
    await trayHost.setStatus(AppTrayStatus.processing);

    final buffer = AudioBuffer(
      samples: List<double>.from(_pcm),
      sampleRate: 16000,
      channels: 1,
    );
    _pcm.clear();

    final result = await speechEngine.transcribe(buffer);
    await speechEngine.stop();

    var text = result.text;
    if (settings.aiEnhancementEnabled &&
        aiProvider != null &&
        text.isNotEmpty) {
      appState.setSession(DictationSessionState.enhancing);
      text = await aiProvider!.enhance(transcript: text);
    }

    appState.setLiveTranscript(text);
    await overlayHost.setTranscript(text);

    if (text.isNotEmpty) {
      appState.setSession(DictationSessionState.injecting);
      await textInjector.insertText(text);
      await history.addFromResult(
        TranscriptResult(text: text, rawText: result.text),
      );
    }

    await overlayHost.hide();
    appState.setSession(DictationSessionState.idle);
    await trayHost.setStatus(AppTrayStatus.idle);
  }

  void _onAudioChunk(AudioChunk chunk) {
    if (appState.session != DictationSessionState.recording) return;
    _pcm.addAll(chunk.samples);
    unawaited(speechEngine.streamAudio(chunk));
  }
}
