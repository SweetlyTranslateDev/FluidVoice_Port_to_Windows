import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

/// MethodChannel for main-window chrome (always-on-top, acrylic).
class WindowChromeChannel {
  WindowChromeChannel({
    MethodChannel channel = const MethodChannel('fluidvoice/window_chrome'),
  }) : _channel = channel;

  final MethodChannel _channel;

  Future<void> setAlwaysOnTop(bool enabled) async {
    await _channel.invokeMethod<void>('setAlwaysOnTop', {'enabled': enabled});
  }

  /// [tint] is the acrylic wash color; alpha controls how strong the tint is.
  Future<void> setAcrylic(
    bool enabled, {
    Color tint = const Color(0xCC171717),
  }) async {
    final argb = tint.toARGB32();
    await _channel.invokeMethod<void>('setAcrylic', {
      'enabled': enabled,
      'a': (argb >> 24) & 0xFF,
      'r': (argb >> 16) & 0xFF,
      'g': (argb >> 8) & 0xFF,
      'b': argb & 0xFF,
    });
  }
}
