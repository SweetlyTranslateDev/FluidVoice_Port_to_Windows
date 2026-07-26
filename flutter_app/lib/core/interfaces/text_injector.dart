/// Focused-app text insertion / selection (UIA → SendInput → clipboard).
abstract class TextInjector {
  Future<void> insertText(String text);

  Future<String?> readSelectedText();
}
