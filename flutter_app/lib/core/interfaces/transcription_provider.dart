import '../models/audio_models.dart';
import '../models/transcript_models.dart';

/// Optional thin alias matching the macOS TranscriptionProvider concept.
///
/// Prefer [SpeechEngine] for new Windows code. This interface exists so
/// domain code can mirror the macOS boundary during the port.
abstract class TranscriptionProvider {
  Future<TranscriptResult> transcribe(AudioBuffer audio);

  Stream<TranscriptEvent>? get streamingTranscripts => null;
}
