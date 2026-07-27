import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:voice_anim_kit/voice_anim_kit.dart';

/// WaveVisualizer-style painter with a thinner main stroke for the pill HUD.
class ThinWaveVisualizer extends StatefulWidget {
  const ThinWaveVisualizer({
    super.key,
    required this.isRecording,
    required this.amplitude,
    this.color,
    this.height = 28.0,
  });

  final bool isRecording;
  final double amplitude;
  final Color? color;
  final double height;

  @override
  State<ThinWaveVisualizer> createState() => _ThinWaveVisualizerState();
}

class _ThinWaveVisualizerState extends State<ThinWaveVisualizer>
    with TickerProviderStateMixin, VisualizerMixin {
  @override
  bool get isRecording => widget.isRecording;

  @override
  double get rawAmplitude => widget.amplitude;

  @override
  Duration get animationDuration => const Duration(milliseconds: 2000);

  @override
  double get noiseThreshold => 0.02;

  @override
  double get amplitudeBoost => 5.5;

  @override
  double get smoothingFactor => 0.28;

  @override
  void initState() {
    super.initState();
    initVisualizer();
  }

  @override
  void didUpdateWidget(ThinWaveVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    updateRecordingState(oldWidget.isRecording);
    updateAmplitude(oldWidget.amplitude);
  }

  @override
  void dispose() {
    disposeVisualizer();
    super.dispose();
  }

  @override
  void onAmplitudeUpdated() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.color ?? Colors.white;
    return FadeTransition(
      opacity: revealAnimation,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: revealAnimation,
          builder: (context, child) {
            return CustomPaint(
              painter: _ThinWavePainter(
                phase: phase,
                amplitude: currentAmplitude,
                revealProgress: revealAnimation.value,
                color: themeColor,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ThinWavePainter extends CustomPainter {
  _ThinWavePainter({
    required this.phase,
    required this.amplitude,
    required this.revealProgress,
    required this.color,
  });

  final double phase;
  final double amplitude;
  final double revealProgress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (revealProgress <= 0.0) return;

    final centerY = size.height / 2;
    final width = size.width;

    void drawWave({
      required double heightScale,
      required double freq,
      required double phaseOffset,
      required double strokeWidth,
      required double alphaScale,
      bool isMain = false,
    }) {
      final paint = Paint()
        ..color = color.withValues(alpha: alphaScale)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final path = Path();
      final center = width / 2;
      final activeHalfWidth = (width / 2) * revealProgress;
      final startX = center - activeHalfWidth;
      final endX = center + activeHalfWidth;
      var isFirst = true;

      for (var x = startX; x <= endX; x += 2) {
        final bell = math.sin(((x - startX) / (endX - startX)) * math.pi);
        final dynAmplitude =
            amplitude * (size.height / 2.0 - strokeWidth) * heightScale;
        final y =
            centerY + math.sin(x * freq + phaseOffset) * dynAmplitude * bell;
        if (isFirst) {
          path.moveTo(x, y);
          isFirst = false;
        } else {
          path.lineTo(x, y);
        }
      }

      if (isMain && amplitude > 0.05) {
        final glowPaint = Paint()
          ..color = color.withValues(alpha: 0.28 * amplitude)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 2.0
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
        canvas.drawPath(path, glowPaint);
      }

      canvas.drawPath(path, paint);
    }

    final baseFreq = (1.5 * 2 * math.pi) / width;

    drawWave(
      heightScale: 0.7,
      freq: baseFreq * 1.3,
      phaseOffset: phase * 1.5,
      strokeWidth: 1.2,
      alphaScale: 0.22,
    );
    drawWave(
      heightScale: 1.0,
      freq: baseFreq * 0.85,
      phaseOffset: -phase * 0.9 + math.pi,
      strokeWidth: 1.6,
      alphaScale: 0.45,
    );
    drawWave(
      heightScale: 1.2,
      freq: baseFreq * 1.0,
      phaseOffset: phase * 1.2,
      strokeWidth: 2.0,
      alphaScale: 1.0,
      isMain: true,
    );
  }

  @override
  bool shouldRepaint(covariant _ThinWavePainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.revealProgress != revealProgress ||
        oldDelegate.color != color;
  }
}
