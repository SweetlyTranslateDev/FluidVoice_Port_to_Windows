import 'package:flutter/material.dart';

import '../features/dictation/dictation_page.dart';
import '../features/history/history_page.dart';
import '../features/models/models_page.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/settings/settings_page.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

class FluidVoiceApp extends StatelessWidget {
  const FluidVoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FluidVoice',
      theme: buildFluidVoiceTheme(),
      initialRoute: AppRoutes.home,
      routes: {
        AppRoutes.home: (_) => const DictationPage(),
        AppRoutes.settings: (_) => const SettingsPage(),
        AppRoutes.history: (_) => const HistoryPage(),
        AppRoutes.models: (_) => const ModelsPage(),
        AppRoutes.onboarding: (_) => const OnboardingPage(),
      },
    );
  }
}
