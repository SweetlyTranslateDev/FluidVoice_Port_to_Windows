library;

class TranscriptEvent {
  const TranscriptEvent({
    required this.text,
    this.isFinal = false,
    this.confidence,
  });

  final String text;
  final bool isFinal;
  final double? confidence;
}

class TranscriptResult {
  const TranscriptResult({
    required this.text,
    this.confidence,
    this.rawText,
  });

  final String text;
  final double? confidence;
  final String? rawText;
}
