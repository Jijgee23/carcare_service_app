import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:carcare_service/core/theme/app_theme.dart';
import 'package:carcare_service/features/models/diagnostic.dart';
import 'package:carcare_service/features/presentation/controllers/controllers.dart';
import 'package:carcare_service/features/presentation/data/repository/diagnostic_repository.dart';
import 'package:carcare_service/features/presentation/pages/inspection/new_inspection_screen.dart';
import 'package:carcare_service/features/presentation/pages/inspection/report_detail_screen.dart';
import 'package:carcare_service/shared/widgets/common/common_widgets.dart';

class VehicleDetailScreen extends StatefulWidget {
  final VehicleSummary vehicle;
  const VehicleDetailScreen({super.key, required this.vehicle});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  List<DiagnosticReportSummary> _reports = [];
  bool _loading = true;
  final _repo = DiagnosticRepository();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _repo.getReports(vehicleId: widget.vehicle.id, pageSize: 100);
    if (mounted) {
      setState(() {
        _reports = result.items;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vehicle;
    final fmt = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      appBar: AppBar(title: Text(v.plate)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'vehicle_detail_fab',
        onPressed: () => _startInspection(context),
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Оношилгоо',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  // ─── Vehicle info card ───────────────────────────────────────
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                              ),
                              child: const Icon(
                                Icons.directions_car,
                                color: AppColors.primary,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    v.plate,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(v.displayName, style: AppTextStyles.body),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        _VehicleInfoRow(label: 'Марка', value: v.make),
                        _VehicleInfoRow(label: 'Загвар', value: v.model),
                        if (v.year != null) _VehicleInfoRow(label: 'Он', value: '${v.year}'),
                        if (v.vin != null && v.vin!.isNotEmpty)
                          _VehicleInfoRow(label: 'VIN', value: v.vin!),
                        if (v.mileage != null)
                          _VehicleInfoRow(label: 'Явсан км', value: '${v.mileage} км'),
                        if (v.customer != null) ...[
                          const Divider(height: 16),
                          Row(
                            children: [
                              const Icon(
                                Icons.person_outline,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(v.customer!.displayName, style: AppTextStyles.captionMedium),
                              const SizedBox(width: 8),
                              Text(v.customer!.phone, style: AppTextStyles.caption),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ─── Report history ──────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Оношилгооны түүх', style: AppTextStyles.h3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                        ),
                        child: Text(
                          '${_reports.length} удаа',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_reports.isEmpty)
                    const EmptyState(message: 'Оношилгоо байхгүй байна', icon: Icons.inbox_outlined)
                  else
                    ..._reports.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ReportDetailScreen(reportId: r.id)),
                          ),
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
                                child: const Icon(
                                  Icons.description_outlined,
                                  color: AppColors.accent,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.template.name, style: AppTextStyles.bodyMedium),
                                    const SizedBox(height: 2),
                                    Text(
                                      r.template.type.label,
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.accent,
                                      ),
                                    ),
                                    Text(fmt.format(r.createdAt), style: AppTextStyles.caption),
                                    if (r.mileageAtReport != null)
                                      Text('${r.mileageAtReport} км', style: AppTextStyles.caption),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: AppColors.textHint),
                            ],
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

class _VehicleInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _VehicleInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(label, style: AppTextStyles.caption)),
          Expanded(child: Text(value, style: AppTextStyles.captionMedium)),
        ],
      ),
    );
  }
}
