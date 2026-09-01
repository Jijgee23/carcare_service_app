import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:carcare_service/core/theme/app_theme.dart';
import 'package:carcare_service/features/models/diagnostic.dart';
import 'package:carcare_service/features/presentation/controllers/controllers.dart';
import 'package:carcare_service/features/presentation/pages/inspection/report_detail_screen.dart';
import 'package:carcare_service/shared/widgets/cards/inspection_cards.dart';
import 'package:carcare_service/shared/mixin/pagination_mixin.dart';
import 'package:carcare_service/shared/widgets/common/common_widgets.dart';

// ─── Pagination footer ────────────────────────────────────────────────────────

class _PaginationFooter extends StatelessWidget {
  final InspectionController prov;
  const _PaginationFooter({required this.prov});

  @override
  Widget build(BuildContext context) {
    if (prov.loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (!prov.hasNext && prov.total > 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text('Нийт ${prov.total} бүртгэл ачааллагдлаа', style: AppTextStyles.caption),
        ),
      );
    }
    return const SizedBox(height: 16);
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with PaginationMixin {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _dateFilter = 'Бүгд';

  static const _dateFilters = ['Бүгд', 'Өнөөдөр', '7 хоног', '1 сар'];

  @override
  void initState() {
    super.initState();
    initPagination(() => context.read<InspectionController>().loadMore());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<InspectionController>().loadReports();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<DiagnosticReportSummary> _getFiltered(List<DiagnosticReportSummary> reports) {
    var list = reports;

    // Date filter
    if (_dateFilter != 'Бүгд') {
      final now = DateTime.now();
      DateTime start;
      if (_dateFilter == 'Өнөөдөр') {
        start = DateTime(now.year, now.month, now.day);
      } else if (_dateFilter == '7 хоног') {
        start = now.subtract(const Duration(days: 7));
      } else {
        start = now.subtract(const Duration(days: 30));
      }
      list = list.where((r) => r.createdAt.isAfter(start)).toList();
    }

    // Text search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where(
            (r) =>
                r.vehicle.plate.toLowerCase().contains(q) ||
                r.customer.displayName.toLowerCase().contains(q) ||
                r.template.name.toLowerCase().contains(q),
          )
          .toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<InspectionController>();
    final filtered = _getFiltered(prov.reports);
    final isFiltering = _dateFilter != 'Бүгд' || _searchQuery.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Бүртгэлийн жагсаалт'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: prov.loadReports)],
      ),
      body: Column(
        children: [
          // ─── Search bar ──────────────────────────────────────────────────
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              decoration: InputDecoration(
                hintText: 'Дугаар, нэр, загвараар хайх...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textHint, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: AppTextStyles.body,
            ),
          ),

          // ─── Date filter chips ───────────────────────────────────────────
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(
              children: _dateFilters.map((f) {
                final active = f == _dateFilter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _dateFilter = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: active ? AppColors.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                        border: Border.all(color: active ? AppColors.accent : AppColors.divider),
                      ),
                      child: Text(
                        f,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: active ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ─── Result count ────────────────────────────────────────────────
          if (isFiltering)
            Container(
              width: double.infinity,
              color: AppColors.accent.withOpacity(0.06),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                '${filtered.length} үр дүн',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          // ─── List ────────────────────────────────────────────────────────
          Expanded(
            child: prov.loading && prov.reports.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? EmptyState(
                    message: isFiltering
                        ? 'Хайлтад тохирох бүртгэл олдсонгүй'
                        : 'Оношилгооны бүртгэл байхгүй байна',
                    icon: Icons.inventory_2_outlined,
                  )
                : RefreshIndicator(
                    onRefresh: prov.loadReports,
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(AppDimens.paddingMD),
                      itemCount: filtered.length + 1,
                      itemBuilder: (_, i) {
                        if (i == filtered.length) {
                          return _PaginationFooter(prov: prov);
                        }
                        final r = filtered[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ReportListCard(
                            report: r,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ReportDetailScreen(reportId: r.id)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
