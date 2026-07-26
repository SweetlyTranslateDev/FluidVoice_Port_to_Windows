import '../interfaces/overlay_host.dart';
import 'overlay_window_channel.dart';

/// Windows overlay host via MethodChannel `fluidvoice/overlay`.
class Win32OverlayHost implements OverlayHost {
  Win32OverlayHost({OverlayWindowChannel? channel})
      : _channel = channel ?? OverlayWindowChannel();

  final OverlayWindowChannel _channel;

  @override
  Future<void> show() => _channel.show();

  @override
  Future<void> hide() => _channel.hide();

  @override
  Future<void> setTranscript(String text) => _channel.setTranscript(text);

  @override
  Future<void> setClickThrough(bool enabled) =>
      _channel.setClickThrough(enabled);

  @override
  Future<void> setPosition({required double x, required double y}) =>
      _channel.setPosition(x: x, y: y);
}
