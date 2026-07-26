import 'package:flutter/services.dart';

/// MethodChannel for the Win32 notify-icon tray (`fluidvoice/tray`).
class TrayChannel {
  TrayChannel({
    MethodChannel channel = const MethodChannel('fluidvoice/tray'),
  }) : _channel = channel;

  final MethodChannel _channel;
  void Function(String id)? onAction;

  void attach() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'action') {
        final id = call.arguments;
        if (id is String) {
          onAction?.call(id);
        }
      }
    });
  }

  Future<void> start() => _channel.invokeMethod<void>('start');

  Future<void> stop() => _channel.invokeMethod<void>('stop');

  Future<void> setTooltip(String text) =>
      _channel.invokeMethod<void>('setTooltip', {'text': text});

  Future<void> setStatus(String status) =>
      _channel.invokeMethod<void>('setStatus', {'status': status});

  Future<void> setMenu(List<Map<String, Object?>> items) =>
      _channel.invokeMethod<void>('setMenu', items);

  Future<void> showApp() => _channel.invokeMethod<void>('showApp');

  Future<void> hideApp() => _channel.invokeMethod<void>('hideApp');

  Future<void> quitApp() => _channel.invokeMethod<void>('quitApp');
}
