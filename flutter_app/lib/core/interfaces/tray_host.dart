import '../models/desktop_models.dart';

/// System tray host (MethodChannel).
abstract class TrayHost {
  Future<void> setStatus(AppTrayStatus status);

  Future<void> setMenu(List<TrayMenuItem> items);

  Stream<TrayAction> get actions;
}
