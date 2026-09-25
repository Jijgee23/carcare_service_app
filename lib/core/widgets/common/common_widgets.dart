import 'package:flutter/material.dart';
import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/domain/models.dart';

class StatusBadge extends StatelessWidget {
  final CheckStatus status;
  final bool compact;
  const StatusBadge({super.key, required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: context.checkStatusBackground(status),
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 13, color: context.checkStatusColor(status)),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: context.checkStatusColor(status),
            ),
          ),
        ],
      ),
    );
  }
}

class StatCounterRow extends StatelessWidget {
  final int good;
  final int warning;
  final int danger;
  const StatCounterRow({
    super.key,
    required this.good,
    required this.warning,
    required this.danger,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Chip(
          count: good,
          label: 'Хэвийн',
          color: context.colors.good,
          bg: context.colors.goodBg,
        ),
        const SizedBox(width: 8),
        _Chip(
          count: warning,
          label: 'Анхаарах',
          color: context.colors.warning,
          bg: context.colors.warningBg,
        ),
        const SizedBox(width: 8),
        _Chip(
          count: danger,
          label: 'Засвар',
          color: context.colors.danger,
          bg: context.colors.dangerBg,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final Color bg;
  const _Chip({
    required this.count,
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimens.radiusSM),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionProgressTabs extends StatelessWidget {
  final List<String> titles;
  final int current;
  final Function(int) onTap;
  const SectionProgressTabs({
    super.key,
    required this.titles,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(titles.length, (i) {
        final isActive = i == current;
        return Expanded(
          child: GestureDetector(
            onTap: () => onTap(i),
            child: Column(
              children: [
                Text(
                  '${i + 1}. ${titles[i]}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    color: isActive
                        ? context.colors.accent
                        : context.colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: isActive
                        ? context.colors.accent
                        : context.colors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? context.colors.cardBg,
      borderRadius: BorderRadius.circular(AppDimens.radiusLG),
      elevation: AppDimens.cardElevation,
      shadowColor: context.colors.textPrimary.withOpacity(0.12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusLG),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(AppDimens.paddingMD),
          child: child,
        ),
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final bool readOnly;
  final VoidCallback? onTap;
  final void Function(String)? onChanged;
  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.keyboardType,
    this.suffixIcon,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.textStyles.captionMedium),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          onTap: onTap,
          onChanged: onChanged,
          style: context.textStyles.body,
          decoration: InputDecoration(hintText: hint, suffixIcon: suffixIcon),
        ),
      ],
    );
  }
}

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool loading;
  final IconData? icon;
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.outlined = false,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton(
        onPressed: onPressed,
        child: Text(
          label,
          style: context.textStyles.buttonText.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      );
    }
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: CarCareTheme.of(context).onAccent,
                strokeWidth: 2,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 6),
                ],
                Text(label),
              ],
            ),
    );
  }
}

class SectionDivider extends StatelessWidget {
  final String? label;
  const SectionDivider({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    if (label == null) return const Divider(height: 24);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label!, style: context.textStyles.label),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: context.colors.textHint),
          const SizedBox(height: 16),
          Text(
            message,
            style: context.textStyles.body.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Inline error state (for AsyncError inside screens) ───────────────────────

class ErrorStateView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final bool _isNotFound;

  const ErrorStateView({super.key, required this.message, this.onRetry})
    : _isNotFound = false;

  const ErrorStateView.notFound({
    super.key,
    this.message = 'Мэдээлэл олдсонгүй',
    this.onRetry,
  }) : _isNotFound = true;

  @override
  Widget build(BuildContext context) {
    final icon = _isNotFound
        ? Icons.search_off_rounded
        : Icons.cloud_off_rounded;
    final iconColor = _isNotFound
        ? context.colors.textHint
        : context.colors.danger;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: iconColor),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: context.textStyles.bodyMedium.copyWith(
                color: context.colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text('Дахин оролдох'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.accent,
                  side: BorderSide(color: context.colors.accent),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Centered progress indicator for loading states. Use instead of a bare
/// `Center(child: CircularProgressIndicator())`.
class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.size, this.padding = EdgeInsets.zero});

  /// Optional fixed diameter, e.g. 20 for inline/button spinners.
  final double? size;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final indicator = CircularProgressIndicator(
      strokeWidth: size != null && size! < 28 ? 2 : 4,
    );
    return Padding(
      padding: padding,
      child: Center(
        child: size == null
            ? indicator
            : SizedBox.square(dimension: size, child: indicator),
      ),
    );
  }
}
