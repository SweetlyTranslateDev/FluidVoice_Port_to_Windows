import 'package:flutter/services.dart';

/// MethodChannel for the native always-on-top transcript overlay.
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

  Future<void> setClickThrough(bool enabled) =>
      _channel.invokeMethod<void>('setClickThrough', {'enabled': enabled});

  Future<void> setPosition({required double x, required double y}) =>
      _channel.invokeMethod<void>('setPosition', {'x': x, 'y': y});
}
