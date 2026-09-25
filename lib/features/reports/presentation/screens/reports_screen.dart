import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/core/widgets/adaptive/async_state_view.dart';
import 'package:carcare_service/core/widgets/common/common_widgets.dart';
import 'package:carcare_service/core/widgets/dialogs/message.dart';
import 'package:carcare_service/core/widgets/mn_date_picker.dart';
import 'package:carcare_service/features/reports/domain/report.dart';
import 'package:carcare_service/features/reports/domain/reports_repository.dart';
import 'package:carcare_service/features/reports/presentation/controllers/report_controller.dart';
import 'package:carcare_service/features/reports/presentation/report_ranges.dart';
import 'package:carcare_service/features/reports/presentation/widgets/report_income_chart.dart';
import 'package:carcare_service/features/reports/presentation/widgets/report_widgets.dart';

/// The Reports screen — P7-F2. Any authenticated staff member may open it
/// (D-174: no `reports.*` permission exists), matching the web's
/// `requireUser()`-only gate.
///
/// **Not wired to a route** — `lib/app/router.dart`/`app_shell.dart` belong
/// to the later `P7-F4` slice. [onExport] is a test/DI seam for the
/// `share_plus` side effect, matching `ReportDetailScreen.onPdfExport`'s
/// precedent: when null, the real `share_plus` share sheet is used.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({
    super.key,
    this.repository,
    this.user,
    this.onExport,
  });

  final ReportsRepository? repository;
  final User? user;
  final Future<void> Function(List<int> bytes, String filename)? onExport;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => ReportController(repo: repository)..load(),
    child: _Body(user: user, onExport: onExport),
  );
}

class _Body extends StatefulWidget {
  const _Body({this.user, this.onExport});

  final User? user;
  final Future<void> Function(List<int> bytes, String filename)? onExport;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  User? get _user => widget.user ?? Authenticator.user;

  Future<void> _pickCustomRange(ReportController controller) async {
    final now = DateTime.now();
    final picked = await showMnDateRangePicker(
      context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialRange: DateTimeRange(
        start: controller.from.isAfter(now) ? now : controller.from,
        end: controller.to.isAfter(now) ? now : controller.to,
      ),
    );
    if (picked == null || !mounted) return;
    await controller.setCustomRange(picked.start, picked.end);
  }

  Future<void> _export(ReportController controller) async {
    final result = await controller.export();
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        await _share(value);
      case Err(:final error):
        messageError(error.display);
    }
  }

  Future<void> _share(ReportExportFile file) async {
    if (file.bytes.isEmpty) {
      messageError('Тайлангийн файл хоосон байна.');
      return;
    }
    final injected = widget.onExport;
    if (injected != null) {
      await injected(file.bytes, file.filename);
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(file.bytes),
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              name: file.filename,
            ),
          ],
          fileNameOverrides: [file.filename],
          subject: 'Тайлан',
        ),
      );
    } catch (_) {
      if (mounted) messageError('Тайлан хуваалцахад алдаа гарлаа.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(
        body: Center(child: Text('Нэвтрэх шаардлагатай')),
      );
    }

    final controller = context.watch<ReportController>();
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Тайлан'),
        actions: [
          IconButton(
            tooltip: 'Excel татах',
            icon: controller.exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download_outlined),
            onPressed: controller.exporting
                ? null
                : () => _export(controller),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          padding: const EdgeInsets.all(AppDimens.paddingMD),
          children: [
            _RangeChipRow(
              controller: controller,
              onCustom: () => _pickCustomRange(controller),
            ),
            const SizedBox(height: 14),
            AsyncStateView<ReportResult>(
              state: controller.state,
              onRetry: controller.load,
              builder: (context, result) =>
                  _ReportContent(range: result.range, data: result.data),
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeChipRow extends StatelessWidget {
  final ReportController controller;
  final VoidCallback onCustom;
  const _RangeChipRow({required this.controller, required this.onCustom});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final key in reportQuickRangeChipOrder)
          ChoiceChip(
            label: Text(reportQuickRangeLabels[key]!),
            selected: controller.quickKey == key,
            onSelected: (_) => controller.setQuickRange(key),
          ),
        ActionChip(
          avatar: const Icon(Icons.date_range_outlined, size: 16),
          label: Text(
            controller.quickKey == ReportQuickRange.custom
                ? '${reportYmd(controller.from)} — ${reportYmd(controller.to)}'
                : 'Хугацаа сонгох',
          ),
          onPressed: onCustom,
        ),
      ],
    );
  }
}

class _ReportContent extends StatelessWidget {
  final ReportRange range;
  final ReportData data;
  const _ReportContent({required this.range, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (range.label != null) ...[
          Text(range.label!, style: context.textStyles.caption),
          const SizedBox(height: 12),
        ],

        // ─── KPI cards ───────────────────────────────────────────────────
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.7,
          children: [
            ReportKpiCard(
              label: 'Нийт орлого',
              value: formatTugrik(data.totalRevenue),
              accent: true,
            ),
            ReportKpiCard(
              label: 'Дууссан засварын хуудас',
              value: '${data.completedCount}',
            ),
            ReportKpiCard(
              label: 'Дундаж дүн',
              value: formatTugrik(data.avgTicket),
            ),
            ReportKpiCard(label: 'Идэвхтэй', value: '${data.activeCount}'),
          ],
        ),
        const SizedBox(height: 10),
        ReportKpiCard(
          label: 'Дундаж гүйцэтгэх хугацаа',
          value: formatReportDuration(data.avgJobDurationMinutes),
        ),
        const SizedBox(height: 14),

        // ─── Income chart ───────────────────────────────────────────────
        ReportSection(
          title: 'Орлогын хандлага',
          subtitle: 'Дууссан засварын хуудасны өдөр тутмын орлого.',
          child: ReportIncomeChart(income: data.income),
        ),
        const SizedBox(height: 14),

        // ─── Status ─────────────────────────────────────────────────────
        ReportSection(
          title: 'Засварын хуудасны статус',
          subtitle: 'Сонгосон хугацааны нийт засварын хуудас.',
          child: data.statusRows.isEmpty
              ? const ReportSectionEmpty()
              : Column(
                  children: [
                    for (final row in data.statusRows)
                      ReportBarRow(
                        label: row.label ?? row.status ?? '—',
                        trailing: '${row.count}',
                        fraction: row.pct / 100,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 14),

        // ─── Kind ───────────────────────────────────────────────────────
        ReportSection(
          title: 'Орлого — ажил, оношилгоо, сэлбэг',
          subtitle: 'Дууссан засварын хуудасны мөрүүдийн хуваарилалт.',
          child: data.kindRows.isEmpty
              ? const ReportSectionEmpty()
              : Column(
                  children: [
                    for (final row in data.kindRows)
                      ReportBarRow(
                        label: row.label ?? row.kind ?? '—',
                        trailing:
                            '${formatTugrik(row.total)} · ${row.pct}%',
                        fraction: row.pct / 100,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 14),

        // ─── Branch ─────────────────────────────────────────────────────
        ReportSection(
          title: 'Салбараар',
          subtitle: 'Орлого ба засварын хуудасны тоо.',
          child: () {
            final maxRevenue = data.branchRows.isEmpty
                ? 1.0
                : data.branchRows
                      .map((r) => r.revenue)
                      .fold<double>(0, (a, b) => b > a ? b : a);
            return ReportRankedList(
              rows: [
                for (final row in data.branchRows)
                  ReportBarRow(
                    label: row.name ?? '—',
                    trailing:
                        '${formatTugrik(row.revenue)} · ${row.count}',
                    fraction: maxRevenue == 0
                        ? 0
                        : row.revenue / maxRevenue,
                  ),
              ],
            );
          }(),
        ),
        const SizedBox(height: 14),

        // ─── Technician ─────────────────────────────────────────────────
        ReportSection(
          title: 'Мастер / Менежер',
          subtitle: 'Хариуцсан засварын хуудасны орлого.',
          child: () {
            final maxRevenue = data.techRows.isEmpty
                ? 1.0
                : data.techRows
                      .map((r) => r.revenue)
                      .fold<double>(0, (a, b) => b > a ? b : a);
            return ReportRankedList(
              rows: [
                for (final row in data.techRows.take(6))
                  ReportBarRow(
                    label: row.name ?? '—',
                    trailing:
                        '${formatTugrik(row.revenue)} · ${row.count}',
                    fraction: maxRevenue == 0
                        ? 0
                        : row.revenue / maxRevenue,
                  ),
              ],
            );
          }(),
        ),
        const SizedBox(height: 14),

        // ─── Job duration ───────────────────────────────────────────────
        ReportSection(
          title: 'Ажлын гүйцэтгэх дундаж хугацаа',
          subtitle:
              'Эхэлсэн-дуусах цаг тэмдэглэгдсэн ажлуудаар (сэлбэгийн төрлөөр).',
          child: ReportRankedList(
            rows: [
              for (var i = 0; i < data.jobDurationRows.length; i++)
                ReportRankedRow(
                  rank: i + 1,
                  title: data.jobDurationRows[i].name ?? '—',
                  subtitle: '${data.jobDurationRows[i].count} удаа',
                  value: formatReportDuration(
                    data.jobDurationRows[i].avgMinutes,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ─── Top customers ──────────────────────────────────────────────
        ReportSection(
          title: 'Топ үйлчлүүлэгчид',
          subtitle: 'Хамгийн их орлого авчирсан.',
          child: ReportRankedList(
            rows: [
              for (var i = 0; i < data.customerRows.length; i++)
                ReportRankedRow(
                  rank: i + 1,
                  title: data.customerRows[i].name ?? '—',
                  subtitle: '${data.customerRows[i].count} засварын хуудас',
                  value: formatTugrik(data.customerRows[i].revenue),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ─── Top parts ──────────────────────────────────────────────────
        ReportSection(
          title: 'Топ сэлбэгүүд',
          subtitle: 'Хамгийн их орлоготой сэлбэг.',
          child: ReportRankedList(
            rows: [
              for (var i = 0; i < data.partRows.length; i++)
                ReportRankedRow(
                  rank: i + 1,
                  title: data.partRows[i].name ?? '—',
                  subtitle: data.partRows[i].sku,
                  value: formatTugrik(data.partRows[i].revenue),
                  caption:
                      '${_qty(data.partRows[i].qty)} ${data.partRows[i].unit ?? ''}',
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  String _qty(double qty) =>
      qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toStringAsFixed(2);
}
