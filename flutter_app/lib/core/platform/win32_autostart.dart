import 'package:flutter/services.dart';

/// Launch-at-login via HKCU Run key (`fluidvoice/autostart`).
class Win32Autostart {
  Win32Autostart({
    MethodChannel channel = const MethodChannel('fluidvoice/autostart'),
  }) : _channel = channel;

  final MethodChannel _channel;

  Future<bool> isEnabled() async {
    final value = await _channel.invokeMethod<bool>('isEnabled');
    return value ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    await _channel.invokeMethod<void>('setEnabled', {'enabled': enabled});
  }
}
