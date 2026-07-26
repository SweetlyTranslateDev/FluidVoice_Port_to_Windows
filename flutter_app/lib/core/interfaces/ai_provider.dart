/// OpenAI-compatible transcript post-processing (Dart HTTP; no C++).
abstract class AIProvider {
  Future<String> enhance({
    required String transcript,
    String? systemPrompt,
  });

  /// Polished rewrite of [transcript].
  Future<String> rewrite({required String transcript}) => enhance(
        transcript: transcript,
        systemPrompt:
            'Rewrite the following dictated text for clarity and grammar. '
            'Preserve meaning. Return only the rewritten text.',
      );

  /// Expand dictation into written prose.
  Future<String> write({required String transcript}) => enhance(
        transcript: transcript,
        systemPrompt:
            'Turn the following rough dictation into clear written prose. '
            'Fix grammar, add punctuation, and improve flow. '
            'Return only the written text.',
      );
}
