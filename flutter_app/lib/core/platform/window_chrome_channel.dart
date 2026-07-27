import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';

/// MethodChannel for always-on-top / minimize behavior; acrylic via [flutter_acrylic].
class WindowChromeChannel {
  WindowChromeChannel._();

  static final WindowChromeChannel instance = WindowChromeChannel._();

  factory WindowChromeChannel() => instance;

  final MethodChannel _channel =
      const MethodChannel('fluidvoice/window_chrome');
  static bool _acrylicReady = false;

  /// Call once from [main] after [WidgetsFlutterBinding.ensureInitialized].
  static Future<void> ensureAcrylicInitialized() async {
    if (!Platform.isWindows || _acrylicReady) return;
    await Window.initialize();
    _acrylicReady = true;
  }

  Future<void> setAlwaysOnTop(bool enabled) async {
    await _channel.invokeMethod<void>('setAlwaysOnTop', {'enabled': enabled});
  }

  /// When true, the minimize button hides to the system tray instead of the taskbar.
  Future<void> setMinimizeToTray(bool enabled) async {
    await _channel.invokeMethod<void>('setMinimizeToTray', {
      'enabled': enabled,
    });
  }

  /// Enables blurred desktop behind translucent Flutter surfaces.
  Future<void> setAcrylic(
    bool enabled, {
    Color tint = const Color(0x99101010),
  }) async {
    if (!Platform.isWindows) return;
    await ensureAcrylicInitialized();
    if (enabled) {
      await Window.setEffect(
        effect: WindowEffect.acrylic,
        color: tint,
        dark: true,
      );
    } else {
      await Window.setEffect(
        effect: WindowEffect.disabled,
        color: const Color(0xFF121212),
        dark: true,
      );
    }
  }
}
