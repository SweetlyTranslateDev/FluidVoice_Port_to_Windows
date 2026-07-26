import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to FluidVoice')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Windows dictation (MVP)',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            const Text('1. Hold F8 to talk (push-to-talk).'),
            const SizedBox(height: 8),
            const Text('2. Release F8 to transcribe and insert into the focused app.'),
            const SizedBox(height: 8),
            const Text('3. Pick a microphone and Whisper model in Settings.'),
            const SizedBox(height: 8),
            const Text(
              '4. Optional: AI enhance/rewrite/write needs an API key '
              '(Credential Manager).',
            ),
            const SizedBox(height: 8),
            const Text(
              '5. Closing the window hides to the tray — Quit from the tray menu.',
            ),
            const Spacer(),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pushReplacementNamed(AppRoutes.home),
              child: const Text('Start dictating'),
            ),
          ],
        ),
      ),
    );
  }
}
