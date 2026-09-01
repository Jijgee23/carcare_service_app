import 'package:carcare_service/core/theme/app_theme.dart';
import 'package:carcare_service/features/models/service_catalog.dart';
import 'package:carcare_service/core/services/service_catalog_service.dart';
import 'package:carcare_service/shared/widgets/common/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ServiceDetailScreen extends StatefulWidget {
  final String serviceId;
  const ServiceDetailScreen({super.key, required this.serviceId});

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  CatalogService? _service;
  bool _loading = true;

  final _numFmt = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final s = await ServiceCatalogService.getService(widget.serviceId);
    if (mounted) {
      setState(() {
        _service = s;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_service == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(message: 'Үйлчилгээ олдсонгүй', icon: Icons.error_outline),
      );
    }

    final s = _service!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(s.name),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.paddingMD),
        children: [
          // ─── Header card ────────────────────────────────────────────
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: s.type.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                      ),
                      child: Icon(s.type.icon, size: 28, color: s.type.color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name, style: AppTextStyles.h3),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _KindChip(kind: s.type),
                              const SizedBox(width: 8),
                              if (!s.isActive)
                                _TagChip(
                                  label: 'Идэвхгүй',
                                  color: AppColors.textSecondary,
                                  bgColor: AppColors.divider,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (s.description != null && s.description!.isNotEmpty) ...[
                  const Divider(height: 20),
                  Text(s.description!, style: AppTextStyles.body),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ─── Pricing card ───────────────────────────────────────────
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Үнэ мэдээлэл', style: AppTextStyles.h3),
                const Divider(height: 20),
                _DetailRow(
                  icon: Icons.sell_outlined,
                  label: 'Зарах үнэ',
                  value:
                      '${_numFmt.format(s.price.toInt())}₮'
                      '${s.unit != null ? ' / ${s.unit!.display}' : ''}',
                  valueStyle: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                if (s.costPrice != null) ...[
                  const SizedBox(height: 8),
                  _DetailRow(
                    icon: Icons.receipt_outlined,
                    label: 'Өртөг',
                    value: '${_numFmt.format(s.costPrice!.toInt())}₮',
                  ),
                  const SizedBox(height: 8),
                  _DetailRow(
                    icon: Icons.trending_up_outlined,
                    label: 'Ашиг',
                    value: '${_numFmt.format((s.price - s.costPrice!).toInt())}₮',
                    valueStyle: AppTextStyles.body.copyWith(color: AppColors.good),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ─── GOODS: Stock card ──────────────────────────────────────
          if (s.type == ServiceKind.GOODS)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Нөөц', style: AppTextStyles.h3),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _StockSummaryBox(
                          label: 'Үлдэгдэл',
                          value: s.stockDisplay,
                          color: s.stockLevel.color,
                          bgColor: s.stockLevel.bgColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StockSummaryBox(
                          label: 'Төлөв',
                          value: s.stockLevel.label,
                          color: s.stockLevel.color,
                          bgColor: s.stockLevel.bgColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // ─── LABOR: Details card ────────────────────────────────────
          if (s.type == ServiceKind.LABOR)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ажлын мэдээлэл', style: AppTextStyles.h3),
                  const Divider(height: 20),
                  if (s.laborCategory != null)
                    _DetailRow(
                      icon: Icons.folder_outlined,
                      label: 'Ангилал',
                      value: s.laborCategory!.name,
                    ),
                  if (s.durationValue != null) ...[
                    const SizedBox(height: 8),
                    _DetailRow(
                      icon: Icons.schedule_outlined,
                      label: 'Зарцуулах хугацаа',
                      value: s.durationDisplay,
                    ),
                  ],
                  if (s.unit != null) ...[
                    const SizedBox(height: 8),
                    _DetailRow(
                      icon: Icons.straighten_outlined,
                      label: 'Хэмжих нэгж',
                      value: s.unit!.name,
                    ),
                  ],
                ],
              ),
            ),

          if (s.type == ServiceKind.LABOR) const SizedBox(height: 14),

          // ─── Code card ──────────────────────────────────────────────
          if (s.code != null)
            AppCard(
              child: _DetailRow(
                icon: Icons.tag,
                label: 'Код (SKU)',
                value: s.code!,
                valueStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ),

          if (s.usageCount != null) ...[
            const SizedBox(height: 14),
            AppCard(
              child: _DetailRow(
                icon: Icons.receipt_long_outlined,
                label: 'Захиалгад ашигласан',
                value: '${s.usageCount} удаа',
              ),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Helper widgets ────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final TextStyle? valueStyle;
  const _DetailRow({required this.icon, required this.label, required this.value, this.valueStyle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(label, style: AppTextStyles.caption),
        const Spacer(),
        Text(value, style: valueStyle ?? AppTextStyles.bodyMedium),
      ],
    );
  }
}

class _KindChip extends StatelessWidget {
  final ServiceKind kind;
  const _KindChip({required this.kind});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kind.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
        border: Border.all(color: kind.color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(kind.icon, size: 11, color: kind.color),
          const SizedBox(width: 4),
          Text(
            kind.label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kind.color),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;
  const _TagChip({required this.label, required this.color, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color),
      ),
    );
  }
}

class _StockSummaryBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bgColor;
  const _StockSummaryBox({
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppDimens.radiusMD),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
