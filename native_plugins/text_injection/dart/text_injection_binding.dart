/// Text injection binding stub (UIA / SendInput).
class TextInjectionBinding {
  const TextInjectionBinding();

  bool get isAvailable => false;

  void insertText(String text) =>
      throw UnimplementedError('text_injection not linked (Phase 1)');
}
