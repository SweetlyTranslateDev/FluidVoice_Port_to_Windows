import 'package:flutter/material.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Onboarding will cover microphone permission guidance, '
          'hotkey setup, and model download once native plugins land.',
        ),
      ),
    );
  }
}
