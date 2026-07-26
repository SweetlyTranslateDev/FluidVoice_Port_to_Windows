import '../interfaces/text_injector.dart';
import 'text_injection_binding.dart';

/// [TextInjector] backed by fluidvoice_inject.dll.
class Win32TextInjector implements TextInjector {
  Win32TextInjector({TextInjectionBinding? binding})
      : _binding = binding ?? TextInjectionBinding.tryOpen();

  final TextInjectionBinding? _binding;

  bool get isNativeAvailable => _binding != null;

  @override
  Future<void> insertText(String text) async {
    final binding = _binding;
    if (binding == null) {
      throw StateError(
        'fluidvoice_inject.dll not found. Build Flutter Windows to produce it.',
      );
    }
    binding.injectText(text);
  }

  @override
  Future<String?> readSelectedText() async {
    final binding = _binding;
    if (binding == null) {
      return null;
    }
    return binding.readSelection();
  }

  /// Toggle system media play/pause (for “pause while dictating”).
  Future<void> mediaPlayPause() async {
    final binding = _binding;
    if (binding == null) {
      return;
    }
    binding.mediaPlayPause();
  }
}
