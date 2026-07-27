import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'app/pill_window_app.dart';
import 'core/platform/window_chrome_channel.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final windowController = await WindowController.fromCurrentEngine();
  if (windowController.arguments == 'pill') {
    await windowManager.ensureInitialized();
    runApp(PillWindowApp(controller: windowController));
    return;
  }

  try {
    await WindowChromeChannel.ensureAcrylicInitialized();
  } catch (_) {
    // Acrylic plugin missing / unsupported — app still runs opaque.
  }
  runApp(const FluidVoiceApp());
}
