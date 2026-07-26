/// OpenAI-compatible transcript enhancement (implemented in Dart HTTP).
abstract class AIProvider {
  Future<String> enhance({
    required String transcript,
    String? systemPrompt,
  });
}
