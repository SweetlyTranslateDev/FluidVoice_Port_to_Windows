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

  Future<void> setAcrylic(bool enabled) async {
    await _channel.invokeMethod<void>('setAcrylic', {'enabled': enabled});
  }
}
