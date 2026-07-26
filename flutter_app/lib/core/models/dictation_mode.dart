/// Post-transcription AI mode (Windows rewrite/write parity).
enum DictationOutputMode {
  /// Inject Whisper output as-is.
  raw,

  /// Light cleanup / punctuation.
  enhance,

  /// Clear rewrite (macOS rewrite parity).
  rewrite,

  /// Expand into written prose (macOS write parity).
  write,
}
