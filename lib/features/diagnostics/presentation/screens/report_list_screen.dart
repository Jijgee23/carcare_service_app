import 'package:carcare_service/app/router.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/core/widgets/adaptive/permission_gate.dart';
import 'package:carcare_service/core/widgets/common/common_widgets.dart';
import 'package:carcare_service/features/diagnostics/data/diagnostics_data_source.dart';
import 'package:carcare_service/features/diagnostics/data/diagnostics_repository.dart';
import 'package:carcare_service/features/diagnostics/domain/diagnostic.dart';
import 'package:carcare_service/features/diagnostics/domain/diagnostics_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ReportListScreen extends StatefulWidget {
  const ReportListScreen({super.key, this.repo, this.user});
  final DiagnosticReportRepository? repo;
  final User? user;

  @override
  State<ReportListScreen> createState() => _ReportListScreenState();
}

class _ReportListScreenState extends State<ReportListScreen> {
  late final DiagnosticReportRepository _repo =
      widget.repo ?? DiagnosticsRepositoryImpl(RemoteDiagnosticsDataSource());
  bool _loading = true;
  String? _error;
  List<DiagnosticReportSummary> _reports = [];

  @override
  void initState() {
    super.initState();
    if (canSeeView(widget.user ?? Authenticator.user, 'diagnostics.view')) {
      _load();
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _repo.getReports(page: 1, pageSize: 50);
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        _reports = value.items;
      case Err(:final error):
        _error = error.display;
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user ?? Authenticator.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Оношилгооны тайлан')),
      floatingActionButton: canSeeView(user, 'diagnostics.create')
          ? FloatingActionButton.extended(
              onPressed: () =>
                  context.push('${AppRoutes.diagnosticsReports}/new'),
              icon: const Icon(Icons.add),
              label: const Text('Шинэ тайлан'),
            )
          : null,
      body: PermissionGate(
        permission: 'diagnostics.view',
        user: user,
        fallback: const EmptyState(
          message: 'Тайлан үзэх эрх хүрэлцэхгүй байна.',
          icon: Icons.lock_outline,
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _Status(message: _error!, action: 'Дахин оролдох', onTap: _load)
            : _reports.isEmpty
            ? const EmptyState(
                message: 'Оношилгооны тайлан алга.',
                icon: Icons.assessment_outlined,
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  itemCount: _reports.length,
                  itemBuilder: (context, index) {
                    final report = _reports[index];
                    return ListTile(
                      leading: const Icon(Icons.assessment_outlined),
                      title: Text(report.template.name),
                      subtitle: Text(
                        '${report.vehicle.plate} · ${report.customer.displayName}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(
                        '${AppRoutes.diagnosticsReports}/${report.id}',
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({
    required this.message,
    required this.action,
    required this.onTap,
  });
  final String message, action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        TextButton(onPressed: onTap, child: Text(action)),
      ],
    ),
  );
}
