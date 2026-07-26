import 'package:flutter/services.dart';

/// MethodChannel stub for overlay / tray-adjacent window control.
///
/// Audio must never use this channel.
class OverlayWindowChannel {
  OverlayWindowChannel({
    MethodChannel channel = const MethodChannel('fluidvoice/overlay'),
  }) : _channel = channel;

  final MethodChannel _channel;

  Future<void> show() => _channel.invokeMethod<void>('show');

  Future<void> hide() => _channel.invokeMethod<void>('hide');

  Future<void> setTranscript(String text) =>
      _channel.invokeMethod<void>('setTranscript', {'text': text});
}
