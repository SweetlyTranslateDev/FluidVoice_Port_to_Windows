/// Floating transcription overlay host (MethodChannel + Flutter window).
abstract class OverlayHost {
  Future<void> show();

  Future<void> hide();

  Future<void> setTranscript(String text);

  Future<void> setClickThrough(bool enabled);

  Future<void> setPosition({required double x, required double y});
}
