import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class FluidCard extends StatelessWidget {
  const FluidCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(FluidSpacing.lg),
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: elevated
            ? FluidColors.elevatedCardBackground
            : FluidColors.cardBackground,
        borderRadius: BorderRadius.circular(FluidRadii.lg),
        border: Border.all(color: FluidColors.cardBorder),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
