import 'dart:async';

import '../interfaces/tray_host.dart';
import '../models/desktop_models.dart';
import 'tray_channel.dart';

/// [TrayHost] backed by MethodChannel `fluidvoice/tray`.
class Win32TrayHost implements TrayHost {
  Win32TrayHost({TrayChannel? channel}) : _channel = channel ?? TrayChannel() {
    _channel.onAction = (id) {
      if (!_actions.isClosed) {
        _actions.add(TrayAction(id));
      }
    };
    _channel.attach();
  }

  final TrayChannel _channel;
  final _actions = StreamController<TrayAction>.broadcast();
  bool _started = false;

  @override
  Stream<TrayAction> get actions => _actions.stream;

  Future<void> start() async {
    if (_started) {
      return;
    }
    await _channel.start();
    await setMenu(const [
      TrayMenuItem(id: 'show', label: 'Show FluidVoice'),
      TrayMenuItem(id: 'settings', label: 'Settings'),
      TrayMenuItem(id: 'quit', label: 'Quit'),
    ]);
    await setStatus(AppTrayStatus.idle);
    _started = true;
  }

  Future<void> showApp() => _channel.showApp();

  Future<void> hideApp() => _channel.hideApp();

  Future<void> quitApp() => _channel.quitApp();

  @override
  Future<void> setStatus(AppTrayStatus status) {
    return _channel.setStatus(status.name);
  }

  @override
  Future<void> setMenu(List<TrayMenuItem> items) {
    return _channel.setMenu([
      for (final item in items)
        {
          'id': item.id,
          'label': item.label,
          'enabled': item.enabled,
        },
    ]);
  }

  Future<void> dispose() async {
    if (_started) {
      await _channel.stop();
      _started = false;
    }
    await _actions.close();
  }
}
