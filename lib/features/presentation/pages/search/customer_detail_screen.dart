import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:carcare_service/core/theme/app_theme.dart';
import 'package:carcare_service/features/models/diagnostic.dart';
import 'package:carcare_service/features/presentation/controllers/controllers.dart';
import 'package:carcare_service/features/presentation/data/repository/diagnostic_repository.dart';
import 'package:carcare_service/features/presentation/pages/inspection/new_inspection_screen.dart';
import 'package:carcare_service/features/presentation/pages/inspection/report_detail_screen.dart';
import 'package:carcare_service/features/presentation/pages/search/vehicle_detail_screen.dart';
import 'package:carcare_service/shared/widgets/common/common_widgets.dart';

class CustomerDetailScreen extends StatefulWidget {
  final CustomerSummary customer;
  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  List<DiagnosticReportSummary> _reports = [];
  List<VehicleSummary> _vehicles = [];
  bool _loading = true;
  final _repo = DiagnosticRepository();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _repo.getReports(customerId: widget.customer.id, pageSize: 100);
    final seen = <String>{};
    final vehicles = <VehicleSummary>[];
    for (final r in result.items) {
      if (seen.add(r.vehicle.id)) {
        vehicles.add(r.vehicle);
      }
    }
    if (mounted) {
      setState(() {
        _reports = result.items;
        _vehicles = vehicles;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;
    return Scaffold(
      appBar: AppBar(
        title: Text(c.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Шинэ оношилгоо',
            onPressed: () => _startInspection(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(AppDimens.paddingMD),
                children: [
                  // ─── Customer header card ────────────────────────────────────
                  AppCard(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AppColors.accent.withOpacity(0.12),
                          child: Text(
                            c.displayName.isNotEmpty ? c.displayName[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.displayName, style: AppTextStyles.h3),
                              const SizedBox(height: 4),
                              _InfoRow(icon: Icons.phone_outlined, text: c.phone),
                              if (c.email != null)
                                _InfoRow(icon: Icons.email_outlined, text: c.email!),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─── Stats row ───────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Машин',
                          count: _vehicles.length,
                          icon: Icons.directions_car_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Оношилгоо',
                          count: _reports.length,
                          icon: Icons.description_outlined,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ─── Vehicles ────────────────────────────────────────────────
                  if (_vehicles.isNotEmpty) ...[
                    Text('Машинууд', style: AppTextStyles.h3),
                    const SizedBox(height: 10),
                    ..._vehicles.map(
                      (v) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicle: v)),
                          ),
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                                ),
                                child: const Icon(
                                  Icons.directions_car_outlined,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(v.plate, style: AppTextStyles.bodyMedium),
                                    Text(v.displayName, style: AppTextStyles.caption),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: AppColors.textHint),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ─── Recent reports ──────────────────────────────────────────
                  Text('Оношилгооны түүх', style: AppTextStyles.h3),
                  const SizedBox(height: 10),
                  if (_reports.isEmpty)
                    const EmptyState(message: 'Оношилгоо байхгүй', icon: Icons.inbox_outlined)
                  else
                    ..._reports.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ReportRow(
                          report: r,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ReportDetailScreen(reportId: r.id)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  void _startInspection(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => NewInspectionController(),
          child: const NewInspectionScreen(),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(text, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final DiagnosticReportSummary report;
  final VoidCallback onTap;
  const _ReportRow({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppDimens.radiusMD),
            ),
            child: const Icon(Icons.description_outlined, color: AppColors.accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(report.vehicle.plate, style: AppTextStyles.bodyMedium),
                Text(
                  report.template.name,
                  style: AppTextStyles.caption.copyWith(color: AppColors.accent),
                ),
                Text(fmt.format(report.createdAt), style: AppTextStyles.caption),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textHint),
        ],
      ),
    );
  }
}
