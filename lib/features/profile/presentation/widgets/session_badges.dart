import 'package:flutter/material.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/widgets/common/common_widgets.dart';
import 'package:carcare_service/features/profile/domain/account_session.dart';

/// Small pill labelling a session row's source — Веб/Мобайл. Web reference:
/// `app/dashboard/profile/page.tsx`'s device list, which tags each row with
/// its `source`.
class SessionSourceTag extends StatelessWidget {
  const SessionSourceTag({super.key, required this.source});

  final AccountSessionSource source;

  @override
  Widget build(BuildContext context) {
    final label = source == AccountSessionSource.web ? 'Веб' : 'Мобайл';
    final icon = source == AccountSessionSource.web
        ? Icons.language_rounded
        : Icons.smartphone_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.colors.divider.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: context.colors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Энэ төхөөрөмж" badge for the row identifying the caller's own device
/// (`AccountSession.current`).
class CurrentDeviceBadge extends StatelessWidget {
  const CurrentDeviceBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.colors.goodBg,
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
      ),
      child: Text(
        'Энэ төхөөрөмж',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.colors.good,
        ),
      ),
    );
  }
}
