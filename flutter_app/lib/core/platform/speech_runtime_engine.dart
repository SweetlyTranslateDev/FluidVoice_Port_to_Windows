import 'dart:async';

import '../interfaces/speech_engine.dart';
import '../models/audio_models.dart';
import '../models/transcript_models.dart';
import 'speech_runtime_binding.dart';
import 'whisper_model_store.dart';

/// [SpeechEngine] backed by native speech_runtime (whisper.cpp).
class SpeechRuntimeEngine implements SpeechEngine {
  SpeechRuntimeEngine({
    SpeechRuntimeBinding? binding,
    WhisperModelStore? modelStore,
  })  : _binding = binding ?? SpeechRuntimeBinding.tryOpen(),
        _models = modelStore ?? WhisperModelStore();

  final SpeechRuntimeBinding? _binding;
  final WhisperModelStore _models;
  final _transcriptController = StreamController<TranscriptEvent>.broadcast();

  bool _initialized = false;
  String? _readyModelId;

  bool get isNativeAvailable => _binding != null;

  @override
  Stream<TranscriptEvent> get transcripts => _transcriptController.stream;

  void _ensureInit() {
    final binding = _binding;
    if (binding == null) {
      throw StateError(
        'fluidvoice_speech.dll not found. Build Flutter Windows to produce it.',
      );
    }
    if (!_initialized) {
      binding.init();
      _initialized = true;
    }
  }

  @override
  Future<void> prepare({required String modelId}) async {
    _ensureInit();
    final path = await _models.ensureModel(modelId);
    _binding!.prepare(path);
    _readyModelId = modelId;
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> streamAudio(AudioChunk chunk) async {
    // Batch path for MVP; streaming segments come later.
  }

  @override
  Future<TranscriptResult> transcribe(AudioBuffer audio) async {
    _ensureInit();
    if (_readyModelId == null) {
      await prepare(modelId: WhisperModelStore.defaultModelId);
    }
    final text = _binding!.transcribe(
      audio.samples,
      sampleRate: audio.sampleRate,
    );
    final result = TranscriptResult(text: text, rawText: text);
    if (!_transcriptController.isClosed && text.isNotEmpty) {
      _transcriptController.add(
        TranscriptEvent(text: text, isFinal: true),
      );
    }
    return result;
  }

  @override
  Future<void> dispose() async {
    if (_initialized) {
      _binding?.shutdown();
      _initialized = false;
    }
    await _transcriptController.close();
  }
}
