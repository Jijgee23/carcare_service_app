import 'package:flutter/material.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/features/diagnostics/domain/diagnostic.dart';

/// Each diagnostic type's tone, the web's `DIAGNOSTIC_TYPE_BADGE` mapped
/// onto the Ops palette.
Color templateTypeColor(BuildContext context, DiagnosticType type) {
  final theme = CarCareTheme.of(context);
  return switch (type) {
    DiagnosticType.INTAKE => theme.accentHi,
    DiagnosticType.POST_SERVICE => theme.ok,
    DiagnosticType.ROUTINE => theme.accent,
    DiagnosticType.DAMAGE_REPORT => theme.warn,
    DiagnosticType.unknown => theme.mutedText2,
  };
}

/// The web's `Chip`: a small pill, tinted by [color] or neutral when none.
class TemplateChip extends StatelessWidget {
  const TemplateChip({super.key, required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = CarCareTheme.of(context);
    final tone = color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone?.withValues(alpha: 0.14) ?? theme.panel2,
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
        border: Border.all(
          color: tone?.withValues(alpha: 0.35) ?? theme.border,
        ),
      ),
      child: Text(
        label,
        style: context.textStyles.caption.copyWith(
          color: tone ?? theme.mutedText2,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
      ),
    );
  }
}
