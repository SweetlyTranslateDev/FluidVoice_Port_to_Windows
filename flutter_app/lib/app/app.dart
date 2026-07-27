import 'package:flutter/material.dart';

import '../features/onboarding/onboarding_page.dart';
import 'routes/app_routes.dart';
import 'shell/app_shell.dart';
import 'shell/shell_navigation.dart';
import 'theme/app_theme.dart';

// Transparent host color helps Win11 acrylic show at the edges.

class FluidVoiceApp extends StatelessWidget {
  const FluidVoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = buildFluidVoiceTheme();
    return MaterialApp(
      title: 'FluidVoice',
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      color: const Color(0x00000000),
      initialRoute: AppRoutes.home,
      routes: {
        AppRoutes.home: (_) => const AppShell(),
        AppRoutes.settings: (_) =>
            const AppShell(initialPage: ShellPage.settings),
        AppRoutes.history: (_) =>
            const AppShell(initialPage: ShellPage.history),
        AppRoutes.models: (_) => const AppShell(initialPage: ShellPage.models),
        AppRoutes.onboarding: (_) => const OnboardingPage(),
      },
    );
  }
}
