import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';

/// Dictation status shell. Wired to DictationController in Phase 1.
class DictationPage extends StatelessWidget {
  const DictationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FluidVoice'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'History',
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.history),
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Windows port scaffold',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text(
              'Phase 0: Dart core interfaces and managers are in place. '
              'WASAPI, hotkeys, speech_runtime, and text injection are not '
              'implemented yet.',
            ),
            SizedBox(height: 24),
            Text('Status: idle (stub)'),
            SizedBox(height: 8),
            Text('Live transcript will appear here.'),
          ],
        ),
      ),
    );
  }
}
