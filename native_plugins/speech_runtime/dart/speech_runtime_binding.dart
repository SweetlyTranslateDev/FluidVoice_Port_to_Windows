/// FFI binding stub for the unified speech_runtime facade.
class SpeechRuntimeBinding {
  const SpeechRuntimeBinding();

  bool get isAvailable => false;

  Never _nyi() =>
      throw UnimplementedError('speech_runtime FFI not linked (Phase 1)');

  void prepare(String modelId) => _nyi();

  String transcribe(List<double> samples, {int sampleRate = 16000}) => _nyi();
}
