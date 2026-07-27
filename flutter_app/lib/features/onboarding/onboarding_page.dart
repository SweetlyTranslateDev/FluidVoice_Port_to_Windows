import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/fluid_card.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(FluidSpacing.xxl),
            child: FluidCard(
              elevated: true,
              padding: const EdgeInsets.all(FluidSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(FluidRadii.md),
                    child: Image.asset(
                      'assets/branding/fluidvoice_logo.png',
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: FluidSpacing.xl),
                  Text('Welcome to FluidVoice', style: theme.textTheme.titleLarge),
                  const SizedBox(height: FluidSpacing.sm),
                  Text(
                    'Windows dictation',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: FluidColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: FluidSpacing.xl),
                  const _Step('Hold your hotkey to talk (push-to-talk).'),
                  const _Step(
                    'Release to transcribe and insert into the focused app.',
                  ),
                  const _Step(
                    'Pick a microphone and speech model (Whisper or Parakeet).',
                  ),
                  const _Step(
                    'Optional: AI enhance needs an API key (Credential Manager).',
                  ),
                  const _Step(
                    'Closing the window hides to the tray — Quit from the tray menu.',
                  ),
                  const SizedBox(height: FluidSpacing.xxl),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context)
                          .pushReplacementNamed(AppRoutes.home),
                      child: const Text('Start dictating'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FluidSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: FluidColors.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: FluidSpacing.md),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
