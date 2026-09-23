import 'package:flutter/material.dart';
import 'package:carcare_service/app/theme/app_theme.dart';

// ─── Full-screen widget-exception error (ErrorWidget.builder) ────────────────

class AppErrorScreen extends StatelessWidget {
  final FlutterErrorDetails? details;
  const AppErrorScreen({super.key, this.details});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: context.colors.danger.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 44,
                    color: context.colors.danger,
                  ),
                ),
                const SizedBox(height: 24),
                Text('Алдаа гарлаа', style: context.textStyles.h2),
                const SizedBox(height: 8),
                Text(
                  'Апп-д гэнэтийн алдаа гарлаа.\nДахин оролдоно уу.',
                  style: context.textStyles.body,
                  textAlign: TextAlign.center,
                ),
                if (details != null) ...[
                  const SizedBox(height: 16),
                  _DebugDetails(details: details!),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final nav = Navigator.of(context, rootNavigator: true);
                      nav.popUntil((route) => route.isFirst);
                    },
                    icon: const Icon(Icons.home_outlined, size: 18),
                    label: Text('Нүүр хуудас руу буцах'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DebugDetails extends StatefulWidget {
  final FlutterErrorDetails details;
  const _DebugDetails({required this.details});

  @override
  State<_DebugDetails> createState() => _DebugDetailsState();
}

class _DebugDetailsState extends State<_DebugDetails> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.dangerBg,
          borderRadius: BorderRadius.circular(AppDimens.radiusSM),
          border: Border.all(color: context.colors.danger.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bug_report_outlined,
                  size: 14,
                  color: context.colors.danger,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Debug мэдээлэл',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.colors.danger,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: context.colors.danger,
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              Text(
                widget.details.exceptionAsString(),
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: context.colors.textPrimary,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Not found screen (navigate to unknown content / 404) ────────────────────

class NotFoundScreen extends StatelessWidget {
  final String? message;
  final VoidCallback? onBack;
  const NotFoundScreen({super.key, this.message, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.brandSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: onBack ?? () => Navigator.of(context).maybePop(),
        ),
        title: Text('Буцах'),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: context.colors.accent.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.search_off_rounded,
                    size: 44,
                    color: context.colors.accent,
                  ),
                ),
                const SizedBox(height: 24),
                Text('Хуудас олдсонгүй', style: context.textStyles.h2),
                const SizedBox(height: 8),
                Text(
                  message ?? 'Таны хайсан хуудас эсвэл мэдээлэл байхгүй байна.',
                  style: context.textStyles.body.copyWith(
                    color: context.colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: Text('Буцах'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.accent,
                      side: BorderSide(color: context.colors.accent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
