import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:carcare_service/core/theme/app_theme.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/models/diagnostic.dart';
import 'package:carcare_service/features/models/models.dart';
import 'package:carcare_service/features/presentation/controllers/controllers.dart';
import 'package:carcare_service/features/presentation/data/repository/diagnostic_repository.dart';
import 'package:carcare_service/shared/widgets/common/common_widgets.dart';
import 'package:carcare_service/shared/widgets/dialogs/confirm_sheet.dart';
import 'package:carcare_service/shared/widgets/dialogs/message.dart';

class ReportDetailScreen extends StatefulWidget {
  final String reportId;
  const ReportDetailScreen({super.key, required this.reportId});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  DiagnosticReportDetail? _report;
  bool _loading = true;
  bool _deleting = false;
  String? _error;
  final _repo = DiagnosticRepository();

  Future<void> _confirmDelete() async {
    final ok = await ConfirmSheet.show(
      context,
      title: 'Тайлан устгах уу?',
      message: 'Энэ оношилгооны тайлан бүрмөсөн устах болно. Энэ үйлдлийг буцаах боломжгүй.',
      confirmLabel: 'Устгах',
      icon: Icons.delete_forever_rounded,
      isDangerous: true,
    );
    if (!ok || !mounted) return;

    setState(() => _deleting = true);
    final result = await _repo.deleteReport(widget.reportId);
    if (!mounted) return;
    setState(() => _deleting = false);

    switch (result) {
      case Ok():
        // Keep the shared list in sync so Home/History reflect the removal.
        context.read<InspectionController>().removeReport(widget.reportId);
        messageComplete('Тайлан устгагдлаа');
        Navigator.pop(context, true);
      case Err(:final error):
        messageError(error.display);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _report = await _repo.getReportDetail(widget.reportId);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тайлангийн дэлгэрэнгүй'),
        actions: [
          if (_report != null)
            _deleting
                ? const Padding(
                    padding: EdgeInsets.only(right: 18),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                    ),
                  )
                : IconButton(
                    tooltip: 'Устгах',
                    icon: const Icon(Icons.delete_outline_rounded, size: 22),
                    onPressed: _confirmDelete,
                  ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(error: _error!, onRetry: _load)
          : _report == null
          ? const Center(child: Text('Тайлан олдсонгүй'))
          : _ReportBody(report: _report!),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
          const SizedBox(height: 12),
          Text(error, style: AppTextStyles.caption, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Дахин оролдох')),
        ],
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  final DiagnosticReportDetail report;
  const _ReportBody({required this.report});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    final status = report.overallStatus;

    return ListView(
      padding: const EdgeInsets.all(AppDimens.paddingMD),
      children: [
        // ─── Толгой мэдээлэл ───────────────────────────────────────────────
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: status.bgColor,
                            borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                          ),
                          child: Text(
                            report.vehicle.plate,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: status.color,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(report.vehicle.displayName, style: AppTextStyles.caption),
                        Text(
                          '${fmt.format(report.createdAt)}${report.mileageAtReport != null ? ' • ${report.mileageAtReport} км' : ''}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _InfoChip(label: 'Загвар', value: report.template.name),
                  const SizedBox(width: 8),
                  _InfoChip(label: 'Салбар', value: report.branch.name),
                ],
              ),
              if (report.filledBy != null) ...[
                const SizedBox(height: 6),
                _InfoChip(label: 'Инженер', value: report.filledBy!.fullName),
              ],
              const SizedBox(height: 14),
              Text('Оношилгооны дүн', style: AppTextStyles.captionMedium),
              const SizedBox(height: 10),
              StatCounterRow(
                good: report.goodCount,
                warning: report.warningCount,
                danger: report.dangerCount,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ─── Хэсэг бүрийн асуулт/хариулт ─────────────────────────────────
        ...report.template.schema.sections.map((section) {
          final items = section.items.where((item) {
            if (item.positionSet != null) {
              // Positioned: дор хаяж нэг байрлалд өгөгдөл байвал харуулна
              return item.positionSet!.positions.any((pos) {
                final entry = report.data[positionedKey(item.id, pos.code)];
                return entry != null &&
                    (entry.value != null || entry.photos?.isNotEmpty == true || entry.note != null);
              });
            }
            final entry = report.data[item.id];
            return entry != null &&
                (entry.value != null || entry.photos?.isNotEmpty == true || entry.note != null);
          }).toList();

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: AppCard(
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  initiallyExpanded: true,
                  title: Text(section.title, style: AppTextStyles.h3),
                  children: items.isEmpty
                      ? [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
                            child: Text('Бөглөгдөөгүй', style: AppTextStyles.caption),
                          ),
                        ]
                      : [
                          const Divider(height: 1),
                          ...items.asMap().entries.map((e) {
                            final item = e.value;
                            final isLast = e.key == items.length - 1;
                            if (item.positionSet != null) {
                              return Column(
                                children: [
                                  _PositionedReportItem(item: item, report: report),
                                  if (!isLast) const Divider(height: 1),
                                ],
                              );
                            }
                            final entry = report.data[item.id]!;
                            return Column(
                              children: [
                                _ReportItemRow(item: item, entry: entry),
                                if (!isLast) const Divider(height: 1),
                              ],
                            );
                          }),
                        ],
                ),
              ),
            ),
          );
        }),

        // ─── Нэмэлт тайлбар ───────────────────────────────────────────────
        if (report.notes?.isNotEmpty == true) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Тайлбар', style: AppTextStyles.h3),
                const SizedBox(height: 8),
                Text(report.notes!, style: AppTextStyles.body),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // ─── Үйлчлүүлэгчийн мэдээлэл ──────────────────────────────────────
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Үйлчлүүлэгч', style: AppTextStyles.h3),
              const SizedBox(height: 10),
              if (report.customer.fullName?.trim().isNotEmpty == true)
                _InfoRow(label: 'Нэр', value: report.customer.fullName!),
              _InfoRow(label: 'Утас', value: report.customer.phone),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ReportItemRow extends StatelessWidget {
  final TemplateItem item;
  final ReportEntry entry;
  const _ReportItemRow({required this.item, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(item.label, style: AppTextStyles.bodyMedium)),
              if (item.type == ItemType.check && entry.value != null)
                StatusBadge(status: entry.checkStatus, compact: true),
              if (item.type != ItemType.check && entry.value != null)
                Text(entry.value.toString(), style: AppTextStyles.caption),
            ],
          ),
          if (entry.note?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(entry.note!, style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic)),
          ],
          if (entry.photos?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: entry.photos!
                    .map(
                      (url) => Container(
                        width: 60,
                        height: 60,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(AppDimens.radiusSM),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppDimens.radiusSM),
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.broken_image, color: AppColors.textHint),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Positioned report item ───────────────────────────────────────────────────

class _PositionedReportItem extends StatelessWidget {
  final TemplateItem item;
  final DiagnosticReportDetail report;
  const _PositionedReportItem({required this.item, required this.report});

  @override
  Widget build(BuildContext context) {
    final positions = item.positionSet!.positions;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.label, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 8),
          ...positions.asMap().entries.map((entry) {
            final i = entry.key;
            final pos = entry.value;
            final key = positionedKey(item.id, pos.code);
            final reportEntry = report.data[key];
            if (reportEntry == null) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (i > 0) const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(AppDimens.radiusSM),
                      ),
                      child: Text(
                        pos.label,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (item.type == ItemType.check && reportEntry.value != null)
                      StatusBadge(status: reportEntry.checkStatus, compact: true),
                    if (item.type != ItemType.check && reportEntry.value != null) ...[
                      const SizedBox(width: 4),
                      Text(reportEntry.value.toString(), style: AppTextStyles.caption),
                    ],
                  ],
                ),
                if (reportEntry.note?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    reportEntry.note!,
                    style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
                if (reportEntry.photos?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 56,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: reportEntry.photos!
                          .map(
                            (url) => Container(
                              width: 56,
                              height: 56,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: AppColors.divider,
                                borderRadius: BorderRadius.circular(AppDimens.radiusSM),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(AppDimens.radiusSM),
                                child: Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.broken_image, color: AppColors.textHint),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: AppTextStyles.caption),
          Text(value, style: AppTextStyles.captionMedium.copyWith(color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(label, style: AppTextStyles.caption)),
          Expanded(child: Text(value, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}
