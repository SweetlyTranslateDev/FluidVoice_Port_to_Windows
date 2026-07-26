import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Speech models'),
            subtitle: const Text('Select via SpeechEngine facade'),
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.models),
          ),
          const ListTile(
            title: Text('Hotkey'),
            subtitle: Text('Configured in SettingsManager (stub)'),
          ),
          const ListTile(
            title: Text('Microphone'),
            subtitle: Text('WASAPI device list (Phase 1)'),
          ),
          const ListTile(
            title: Text('AI enhancement'),
            subtitle: Text('OpenAI-compatible AIProvider (Dart HTTP)'),
          ),
        ],
      ),
    );
  }
}
