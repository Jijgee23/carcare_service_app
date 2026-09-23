import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/widgets/common/common_widgets.dart';
import 'package:carcare_service/features/profile/domain/account_session.dart';
import 'package:carcare_service/features/profile/presentation/widgets/session_badges.dart';

String _fmtDateTime(DateTime? d) {
  if (d == null) return '—';
  return DateFormat('yyyy-MM-dd HH:mm').format(d);
}

/// One active-session row: device label, source tag, "Энэ төхөөрөмж" badge
/// when [AccountSession.current], ip, last activity, and a revoke button.
/// Matches `app/dashboard/profile/page.tsx`'s active-device row.
class ActiveSessionTile extends StatelessWidget {
  const ActiveSessionTile({
    super.key,
    required this.session,
    required this.onRevoke,
    this.busy = false,
  });

  final AccountSession session;
  final VoidCallback? onRevoke;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      s.deviceLabel.isNotEmpty ? s.deviceLabel : 'Төхөөрөмж',
                      style: context.textStyles.bodyMedium,
                    ),
                    SessionSourceTag(source: s.source),
                    if (s.current) const CurrentDeviceBadge(),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  s.ip != null ? 'IP: ${s.ip}' : 'IP: —',
                  style: context.textStyles.caption,
                ),
                const SizedBox(height: 2),
                Text(
                  'Сүүлд идэвхтэй: ${_fmtDateTime(s.lastActivityAt)}',
                  style: context.textStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              tooltip: s.current ? 'Энэ төхөөрөмжөөс гарах' : 'Гаргах',
              onPressed: busy ? null : onRevoke,
              icon: busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.colors.danger,
                      ),
                    )
                  : Icon(
                      Icons.logout_rounded,
                      size: 20,
                      color: context.colors.danger,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One ended-session row (revoked/expired) — no actions, read-only history.
class EndedSessionTile extends StatelessWidget {
  const EndedSessionTile({super.key, required this.session});

  final AccountSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final statusLabel = s.status == AccountSessionStatus.revoked
        ? 'Гарсан'
        : 'Хугацаа дууссан';
    final statusDate = s.revokedAt ?? s.expiresAt;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      s.deviceLabel.isNotEmpty ? s.deviceLabel : 'Төхөөрөмж',
                      style: context.textStyles.bodyMedium.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                    SessionSourceTag(source: s.source),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  s.ip != null ? 'IP: ${s.ip}' : 'IP: —',
                  style: context.textStyles.caption,
                ),
                const SizedBox(height: 2),
                Text(
                  '$statusLabel · ${_fmtDateTime(statusDate)}',
                  style: context.textStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
