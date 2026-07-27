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
      backgroundColor: FluidColors.windowBackground,
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
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: FluidColors.accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(FluidRadii.sm),
                      border: Border.all(
                        color: FluidColors.accent.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      'F',
                      style: fluidText(
                        color: FluidColors.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: FluidSpacing.xl),
                  Text('Welcome to FluidVoice', style: theme.textTheme.titleLarge),
                  const SizedBox(height: FluidSpacing.sm),
                  Text(
                    'Windows dictation MVP',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: FluidColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: FluidSpacing.xl),
                  const _Step('Hold F8 to talk (push-to-talk).'),
                  const _Step(
                    'Release F8 to transcribe and insert into the focused app.',
                  ),
                  const _Step(
                    'Pick a microphone and Whisper model in Settings.',
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
