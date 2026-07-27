import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../theme/app_theme.dart';
import '../../core/services/dictation_hud_controller.dart';
import 'thin_wave_visualizer.dart';

/// Pill + centered transcript card with a thin WaveVisualizer-style waveform.
class FloatingDictationHud extends StatelessWidget {
  const FloatingDictationHud({
    super.key,
    required this.phase,
    required this.amplitude,
    required this.transcript,
    this.onClose,
  });

  final DictationHudPhase phase;
  final double amplitude;
  final String transcript;
  final VoidCallback? onClose;

  Color _phaseColor(DictationHudPhase phase) {
    switch (phase) {
      case DictationHudPhase.listening:
        return FluidColors.danger;
      case DictationHudPhase.processing:
        return FluidColors.warning;
      case DictationHudPhase.error:
        return FluidColors.danger;
      case DictationHudPhase.idle:
        return FluidColors.accent;
    }
  }

  String _phaseLabel(DictationHudPhase phase) {
    switch (phase) {
      case DictationHudPhase.listening:
        return 'Listening';
      case DictationHudPhase.processing:
        return 'Working';
      case DictationHudPhase.error:
        return 'Error';
      case DictationHudPhase.idle:
        return 'Ready';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _phaseColor(phase);
    final listening = phase == DictationHudPhase.listening;
    final amp = listening
        ? amplitude
        : (phase == DictationHudPhase.processing ? 0.35 : 0.08);
    final transcriptText = transcript.isNotEmpty
        ? transcript
        : (phase == DictationHudPhase.processing
            ? 'Transcribing…'
            : (phase == DictationHudPhase.listening
                ? 'Listening…'
                : 'Transcript'));

    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: SizedBox(
              width: 196,
              height: 56,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    child: DragToMoveArea(
                      child: MouseRegion(
                        cursor: SystemMouseCursors.move,
                        child: _RaisedPill(
                          width: 176,
                          height: 56,
                          accent: accent,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ThinWaveVisualizer(
                                    isRecording: listening,
                                    amplitude: amp.clamp(0.0, 1.0),
                                    color: accent,
                                    height: 22,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _phaseLabel(phase),
                                  style: fluidText(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: FluidColors.primaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (onClose != null)
                    Positioned(
                      right: 0,
                      top: -2,
                      child: Material(
                        color: FluidColors.elevatedCardBackground,
                        shape: const CircleBorder(),
                        elevation: 4,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onClose,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: FluidColors.secondaryText,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 280,
                maxWidth: 300,
                minHeight: 72,
                maxHeight: 140,
              ),
              child: Container(
                width: 300,
                padding: const EdgeInsets.all(FluidSpacing.lg),
                decoration: BoxDecoration(
                  color: FluidColors.elevatedCardBackground.withValues(
                    alpha: 0.94,
                  ),
                  borderRadius: BorderRadius.circular(FluidRadii.lg),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Text(
                    transcriptText,
                    textAlign: TextAlign.center,
                    style: fluidText(
                      fontSize: 13,
                      height: 1.4,
                      color: transcript.isEmpty
                          ? FluidColors.tertiaryText
                          : FluidColors.primaryText,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RaisedPill extends StatelessWidget {
  const _RaisedPill({
    required this.width,
    required this.height,
    required this.accent,
    required this.child,
  });

  final double width;
  final double height;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(FluidColors.elevatedCardBackground, Colors.white, 0.08)!,
            FluidColors.cardBackground,
            Color.lerp(FluidColors.cardBackground, Colors.black, 0.25)!,
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
        border: Border.all(
          color: accent.withValues(alpha: 0.55),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.22),
            blurRadius: 18,
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: child,
      ),
    );
  }
}
