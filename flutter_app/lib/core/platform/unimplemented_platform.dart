import 'dart:async';

import '../interfaces/ai_provider.dart';
import '../interfaces/audio_capture.dart';
import '../interfaces/credentials_store.dart';
import '../interfaces/hotkey_source.dart';
import '../interfaces/overlay_host.dart';
import '../interfaces/speech_engine.dart';
import '../interfaces/text_injector.dart';
import '../interfaces/tray_host.dart';
import '../models/audio_models.dart';
import '../models/desktop_models.dart';
import '../models/hotkey_models.dart';
import '../models/transcript_models.dart';

/// Phase 0 stubs: interfaces exist; Win32/WASAPI/whisper not implemented yet.
class UnimplementedAudioCapture implements AudioCapture {
  final _controller = StreamController<AudioChunk>.broadcast();

  @override
  Stream<AudioChunk> get audioStream => _controller.stream;

  @override
  Future<List<AudioDeviceInfo>> listDevices() async =>
      throw UnimplementedError('WASAPI audio capture not implemented (Phase 1)');

  @override
  Future<void> setDevice(String deviceId) async {}

  @override
  Future<void> start() async =>
      throw UnimplementedError('WASAPI audio capture not implemented (Phase 1)');

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

class UnimplementedSpeechEngine implements SpeechEngine {
  final _controller = StreamController<TranscriptEvent>.broadcast();

  @override
  Stream<TranscriptEvent> get transcripts => _controller.stream;

  @override
  Future<void> prepare({required String modelId}) async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> streamAudio(AudioChunk chunk) async {}

  @override
  Future<TranscriptResult> transcribe(AudioBuffer audio) async =>
      throw UnimplementedError('speech_runtime not implemented (Phase 1)');

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

class UnimplementedHotkeySource implements HotkeySource {
  final _controller = StreamController<HotkeyEvent>.broadcast();

  @override
  Stream<HotkeyEvent> get events => _controller.stream;

  @override
  Future<void> setShortcut(HotkeyShortcut shortcut) async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}

class UnimplementedTextInjector implements TextInjector {
  @override
  Future<void> insertText(String text) async =>
      throw UnimplementedError('text injection not implemented (Phase 1)');

  @override
  Future<String?> readSelectedText() async => null;
}

class UnimplementedTrayHost implements TrayHost {
  final _controller = StreamController<TrayAction>.broadcast();

  @override
  Stream<TrayAction> get actions => _controller.stream;

  @override
  Future<void> setMenu(List<TrayMenuItem> items) async {}

  @override
  Future<void> setStatus(AppTrayStatus status) async {}
}

class UnimplementedOverlayHost implements OverlayHost {
  @override
  Future<void> hide() async {}

  @override
  Future<void> setClickThrough(bool enabled) async {}

  @override
  Future<void> setPosition({required double x, required double y}) async {}

  @override
  Future<void> setTranscript(String text) async {}

  @override
  Future<void> show() async {}
}

class UnimplementedCredentialsStore implements CredentialsStore {
  @override
  Future<void> deleteSecret(String key) async {}

  @override
  Future<String?> readSecret(String key) async => null;

  @override
  Future<void> writeSecret(String key, String value) async {}
}

class NoOpAIProvider implements AIProvider {
  @override
  Future<String> enhance({
    required String transcript,
    String? systemPrompt,
  }) async =>
      transcript;

  @override
  Future<String> rewrite({required String transcript}) async => transcript;

  @override
  Future<String> write({required String transcript}) async => transcript;
}
