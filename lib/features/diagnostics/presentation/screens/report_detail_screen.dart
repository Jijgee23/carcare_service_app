import 'package:carcare_service/app/shell/shell_chrome.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/core/domain/diagnostic.dart' as legacy;
import 'package:carcare_service/core/domain/models.dart';
import 'package:carcare_service/features/controllers.dart';
import 'package:carcare_service/features/diagnostics/data/diagnostics_data_source.dart';
import 'package:carcare_service/features/diagnostics/data/diagnostics_repository.dart';
import 'package:carcare_service/features/diagnostics/domain/diagnostic.dart'
    as typed;
import 'package:carcare_service/features/diagnostics/domain/diagnostics_repository.dart';
import 'package:carcare_service/core/widgets/adaptive/permission_gate.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/widgets/common/common_widgets.dart';
import 'package:carcare_service/core/widgets/dialogs/confirm_sheet.dart';
import 'package:carcare_service/core/widgets/dialogs/message.dart';
import 'package:share_plus/share_plus.dart';

class ReportDetailScreen extends StatefulWidget {
  final String reportId;
  final Future<void> Function(String reportId)? onPdfExport;
  const ReportDetailScreen({
    super.key,
    required this.reportId,
    this.onPdfExport,
  });

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  typed.DiagnosticReportDetail? _report;
  bool _loading = true;
  bool _deleting = false;
  String? _error;
  final DiagnosticReportRepository _repo = DiagnosticsRepositoryImpl(
    RemoteDiagnosticsDataSource(),
  );
  DiagnosticAnswerTone _tone = DiagnosticAnswerTone.all;

  Future<void> _exportPdf() async {
    final injectedExport = widget.onPdfExport;
    if (injectedExport != null) {
      await injectedExport(widget.reportId);
      return;
    }

    final result = await _repo.getPdfBytes(widget.reportId);
    if (!mounted) return;
    switch (result) {
      case Err(:final error):
        messageError(error.display);
      case Ok(:final value):
        if (value.isEmpty) {
          messageError('PDF файл хоосон байна.');
          return;
        }
        try {
          await SharePlus.instance.share(
            ShareParams(
              files: [
                XFile.fromData(
                  Uint8List.fromList(value),
                  mimeType: 'application/pdf',
                  name: 'diagnostic-${widget.reportId}.pdf',
                ),
              ],
              fileNameOverrides: ['diagnostic-${widget.reportId}.pdf'],
              subject: 'Оношилгооны тайлан',
            ),
          );
        } catch (_) {
          if (mounted) messageError('PDF хуваалцахад алдаа гарлаа.');
        }
    }
  }

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
      final result = await _repo.getReport(widget.reportId);
      switch (result) {
        case Ok(:final value):
          _report = value;
        case Err(:final error):
          _error = error.display;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Authenticator.user;
    final canDelete = canDeleteDiagnosticReport(
      user: user,
      filledById: _report?.filledById,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text('Тайлангийн дэлгэрэнгүй'),
        actions: [
          if (_report != null)
            IconButton(
              tooltip: 'PDF татах',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: _exportPdf,
            ),
          if (_report != null && canDelete)
            _deleting
                ? Padding(
                    padding: EdgeInsets.only(right: 18),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: CarCareTheme.of(context).onAccent,
                        ),
                      ),
                    ),
                  )
                : IconButton(
                    tooltip: 'Устгах',
                    icon: const Icon(Icons.delete_outline_rounded, size: 22),
                    onPressed: _confirmDelete,
                  ),
          const ShellNotificationBell(),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(error: _error!, onRetry: _load)
          : _report == null
          ? const Center(child: Text('Тайлан олдсонгүй'))
          : PermissionGate(
              permission: 'diagnostics.view',
              child: _ReportBody(
                report: _report!,
                selectedTone: _tone,
                onToneChanged: (tone) => setState(() => _tone = tone),
                onPdfExport: widget.onPdfExport,
              ),
            ),
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
          Icon(Icons.error_outline, color: context.colors.danger, size: 48),
          const SizedBox(height: 12),
          Text(
            error,
            style: context.textStyles.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: Text('Дахин оролдох')),
        ],
      ),
    );
  }
}

enum DiagnosticAnswerTone { all, good, warn, bad }

bool canDeleteDiagnosticReport({
  required User? user,
  required String? filledById,
}) =>
    user?.isOwner == true ||
    (user != null &&
        (filledById == user.id || canSeeView(user, 'diagnostics.delete')));

String _toneLabel(DiagnosticAnswerTone tone) => switch (tone) {
  DiagnosticAnswerTone.good => 'Хэвийн',
  DiagnosticAnswerTone.warn => 'Анхаарах',
  DiagnosticAnswerTone.bad => 'Засах',
  DiagnosticAnswerTone.all => 'Бүгд',
};

CheckStatus _legacyStatus(typed.CheckStatus status) => switch (status) {
  typed.CheckStatus.good => CheckStatus.good,
  typed.CheckStatus.warning => CheckStatus.warning,
  typed.CheckStatus.danger => CheckStatus.danger,
};

bool diagnosticAnswerMatchesTone(Object? value, DiagnosticAnswerTone tone) =>
    tone == DiagnosticAnswerTone.all || _answerTone(value) == tone;

DiagnosticAnswerTone _answerTone(Object? value) => switch (value?.toString()) {
  'OK' => DiagnosticAnswerTone.good,
  'Анхаарах' => DiagnosticAnswerTone.warn,
  'Засах' => DiagnosticAnswerTone.bad,
  _ => DiagnosticAnswerTone.all,
};

Map<DiagnosticAnswerTone, int> diagnosticToneCounts(Iterable<Object?> values) {
  final tones = values.map(_answerTone);
  return {
    DiagnosticAnswerTone.good: tones
        .where((t) => t == DiagnosticAnswerTone.good)
        .length,
    DiagnosticAnswerTone.warn: tones
        .where((t) => t == DiagnosticAnswerTone.warn)
        .length,
    DiagnosticAnswerTone.bad: tones
        .where((t) => t == DiagnosticAnswerTone.bad)
        .length,
  };
}

class _ReportBody extends StatelessWidget {
  final typed.DiagnosticReportDetail report;
  final DiagnosticAnswerTone selectedTone;
  final ValueChanged<DiagnosticAnswerTone> onToneChanged;
  final Future<void> Function(String reportId)? onPdfExport;
  const _ReportBody({
    required this.report,
    required this.selectedTone,
    required this.onToneChanged,
    required this.onPdfExport,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    final status = _legacyStatus(report.overallStatus);
    final counts = diagnosticToneCounts(report.data.values.map((e) => e.value));

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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: context.checkStatusBackground(status),
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusFull,
                            ),
                          ),
                          child: Text(
                            report.vehicle.plate,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.checkStatusColor(status),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          report.vehicle.displayName,
                          style: context.textStyles.caption,
                        ),
                        Text(
                          '${fmt.format(report.createdAt ?? DateTime.now())}${report.mileageAtReport != null ? ' • ${report.mileageAtReport} км' : ''}',
                          style: context.textStyles.caption,
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
              Text('Оношилгооны дүн', style: context.textStyles.captionMedium),
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

        Wrap(
          spacing: 8,
          children: [
            for (final tone in DiagnosticAnswerTone.values)
              FilterChip(
                label: Text(
                  tone == DiagnosticAnswerTone.all
                      ? 'Бүгд (${counts.values.fold<int>(0, (a, b) => a + b)})'
                      : '${_toneLabel(tone)} (${counts[tone]})',
                ),
                selected: selectedTone == tone,
                onSelected: (_) => onToneChanged(tone),
              ),
          ],
        ),
        const SizedBox(height: 14),

        // ─── Хэсэг бүрийн асуулт/хариулт ─────────────────────────────────
        ...report.template.schema.sections.map((section) {
          final items = section.items.where((item) {
            if (item.positionSet != null) {
              // Positioned: дор хаяж нэг байрлалд өгөгдөл байвал харуулна
              return item.positionSet!.positions.any((pos) {
                final entry =
                    report.data[legacy.positionedKey(item.id, pos.code)];
                return entry != null &&
                    diagnosticAnswerMatchesTone(entry.value, selectedTone) &&
                    (entry.value != null ||
                        entry.photos?.isNotEmpty == true ||
                        entry.note != null);
              });
            }
            final entry = report.data[item.id];
            return entry != null &&
                diagnosticAnswerMatchesTone(entry.value, selectedTone) &&
                (entry.value != null ||
                    entry.photos?.isNotEmpty == true ||
                    entry.note != null);
          }).toList();

          if (selectedTone != DiagnosticAnswerTone.all && items.isEmpty) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: AppCard(
              child: Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  initiallyExpanded: true,
                  title: Text(section.title, style: context.textStyles.h3),
                  children: items.isEmpty
                      ? [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
                            child: Text(
                              'Бөглөгдөөгүй',
                              style: context.textStyles.caption,
                            ),
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
                                  _PositionedReportItem(
                                    item: item,
                                    report: report,
                                  ),
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
                Text('Тайлбар', style: context.textStyles.h3),
                const SizedBox(height: 8),
                Text(report.notes!, style: context.textStyles.body),
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
              Text('Үйлчлүүлэгч', style: context.textStyles.h3),
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
  final typed.TemplateItem item;
  final typed.ReportEntry entry;
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
              Expanded(
                child: Text(item.label, style: context.textStyles.bodyMedium),
              ),
              if (item.type == typed.ItemType.check && entry.value != null)
                StatusBadge(
                  status: _legacyStatus(entry.checkStatus),
                  compact: true,
                ),
              if (item.type != typed.ItemType.check && entry.value != null)
                Text(entry.value.toString(), style: context.textStyles.caption),
            ],
          ),
          if (entry.note?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              entry.note!,
              style: context.textStyles.caption.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
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
                          color: context.colors.divider,
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusSM,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusSM,
                          ),
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.broken_image,
                              color: context.colors.textHint,
                            ),
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
  final typed.TemplateItem item;
  final typed.DiagnosticReportDetail report;
  const _PositionedReportItem({required this.item, required this.report});

  @override
  Widget build(BuildContext context) {
    final positions = item.positionSet!.positions;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.label, style: context.textStyles.bodyMedium),
          const SizedBox(height: 8),
          ...positions.asMap().entries.map((entry) {
            final i = entry.key;
            final pos = entry.value;
            final key = legacy.positionedKey(item.id, pos.code);
            final reportEntry = report.data[key];
            if (reportEntry == null) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (i > 0) const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(AppDimens.radiusSM),
                      ),
                      child: Text(
                        pos.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: context.colors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (item.type == typed.ItemType.check &&
                        reportEntry.value != null)
                      StatusBadge(
                        status: _legacyStatus(reportEntry.checkStatus),
                        compact: true,
                      ),
                    if (item.type != typed.ItemType.check &&
                        reportEntry.value != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        reportEntry.value.toString(),
                        style: context.textStyles.caption,
                      ),
                    ],
                  ],
                ),
                if (reportEntry.note?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    reportEntry.note!,
                    style: context.textStyles.caption.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
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
                                color: context.colors.divider,
                                borderRadius: BorderRadius.circular(
                                  AppDimens.radiusSM,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppDimens.radiusSM,
                                ),
                                child: Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Icon(
                                    Icons.broken_image,
                                    color: context.colors.textHint,
                                  ),
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
        color: context.colors.background,
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
        border: Border.all(color: context.colors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: context.textStyles.caption),
          Text(
            value,
            style: context.textStyles.captionMedium.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
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
          SizedBox(
            width: 60,
            child: Text(label, style: context.textStyles.caption),
          ),
          Expanded(child: Text(value, style: context.textStyles.body)),
        ],
      ),
    );
  }
}
