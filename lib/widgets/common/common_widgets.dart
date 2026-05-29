import 'package:flutter/material.dart';
import 'package:carcare_service/core/theme/app_theme.dart';
import 'package:carcare_service/models/models.dart';

class StatusBadge extends StatelessWidget {
  final CheckStatus status;
  final bool compact;
  const StatusBadge({super.key, required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(color: status.bgColor, borderRadius: BorderRadius.circular(AppDimens.radiusFull)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 13, color: status.color),
          const SizedBox(width: 4),
          Text(status.label, style: TextStyle(fontSize: compact ? 11 : 12, fontWeight: FontWeight.w600, color: status.color)),
        ],
      ),
    );
  }
}

class CheckItemRow extends StatelessWidget {
  final CheckItem item;
  final bool editable;
  final Function(CheckStatus)? onStatusChanged;
  const CheckItemRow({super.key, required this.item, this.editable = false, this.onStatusChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(item.name, style: AppTextStyles.bodyMedium)),
          if (editable)
            _EditableStatus(status: item.status, onChanged: onStatusChanged)
          else
            StatusBadge(status: item.status, compact: true),
        ],
      ),
    );
  }
}

class _EditableStatus extends StatelessWidget {
  final CheckStatus status;
  final Function(CheckStatus)? onChanged;
  const _EditableStatus({required this.status, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<CheckStatus>(
      initialValue: status,
      onSelected: onChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusMD)),
      child: StatusBadge(status: status, compact: true),
      itemBuilder: (_) => CheckStatus.values
          .map((s) => PopupMenuItem(
                value: s,
                child: Row(children: [Icon(s.icon, color: s.color, size: 16), const SizedBox(width: 8), Text(s.label, style: AppTextStyles.body)]),
              ))
          .toList(),
    );
  }
}

class StatCounterRow extends StatelessWidget {
  final int good;
  final int warning;
  final int danger;
  const StatCounterRow({super.key, required this.good, required this.warning, required this.danger});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Chip(count: good, label: 'Хэвийн', color: AppColors.good, bg: AppColors.goodBg),
        const SizedBox(width: 8),
        _Chip(count: warning, label: 'Анхаарах', color: AppColors.warning, bg: AppColors.warningBg),
        const SizedBox(width: 8),
        _Chip(count: danger, label: 'Засвар', color: AppColors.danger, bg: AppColors.dangerBg),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final Color bg;
  const _Chip({required this.count, required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppDimens.radiusSM)),
      child: Column(children: [
        Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class SectionProgressTabs extends StatelessWidget {
  final List<String> titles;
  final int current;
  final Function(int) onTap;
  const SectionProgressTabs({super.key, required this.titles, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(titles.length, (i) {
        final isActive = i == current;
        return Expanded(
          child: GestureDetector(
            onTap: () => onTap(i),
            child: Column(children: [
              Text('${i + 1}. ${titles[i]}',
                  style: TextStyle(fontSize: 12, fontWeight: isActive ? FontWeight.w700 : FontWeight.w400, color: isActive ? AppColors.accent : AppColors.textSecondary),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Container(height: 2, decoration: BoxDecoration(color: isActive ? AppColors.accent : AppColors.divider, borderRadius: BorderRadius.circular(2))),
            ]),
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
  const AppCard({super.key, required this.child, this.padding, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? AppColors.cardBg,
      borderRadius: BorderRadius.circular(AppDimens.radiusLG),
      elevation: AppDimens.cardElevation,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusLG),
        child: Padding(padding: padding ?? const EdgeInsets.all(AppDimens.paddingMD), child: child),
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
  const AppTextField({super.key, required this.label, this.hint, this.controller, this.keyboardType, this.suffixIcon, this.readOnly = false, this.onTap, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.captionMedium),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller, keyboardType: keyboardType,
          readOnly: readOnly, onTap: onTap, onChanged: onChanged,
          style: AppTextStyles.body,
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
  const AppButton({super.key, required this.label, this.onPressed, this.outlined = false, this.loading = false, this.icon});

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton(
        onPressed: onPressed,
        child: Text(label, style: AppTextStyles.buttonText.copyWith(color: AppColors.textSecondary)),
      );
    }
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
              Text(label),
            ]),
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
      child: Row(children: [
        const Expanded(child: Divider()),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(label!, style: AppTextStyles.label)),
        const Expanded(child: Divider()),
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const EmptyState({super.key, required this.message, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 64, color: AppColors.textHint),
        const SizedBox(height: 16),
        Text(message, style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
      ]),
    );
  }
}
