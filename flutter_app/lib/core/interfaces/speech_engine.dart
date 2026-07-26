import '../models/audio_models.dart';
import '../models/transcript_models.dart';

/// Unified STT facade. App code must not call per-model plugins.
///
/// Backends live under native_plugins/speech_runtime/.
abstract class SpeechEngine {
  Future<void> prepare({required String modelId});

  Future<void> start();

  Future<void> stop();

  Future<void> streamAudio(AudioChunk chunk);

  Stream<TranscriptEvent> get transcripts;

  Future<TranscriptResult> transcribe(AudioBuffer audio);

  Future<void> dispose();
}
