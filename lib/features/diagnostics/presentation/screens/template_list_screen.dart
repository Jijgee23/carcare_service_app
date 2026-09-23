import 'package:carcare_service/app/router.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/core/widgets/adaptive/permission_gate.dart';
import 'package:carcare_service/core/widgets/common/common_widgets.dart';
import 'package:carcare_service/core/widgets/dialogs/message.dart';
import 'package:carcare_service/features/diagnostics/data/diagnostics_data_source.dart';
import 'package:carcare_service/features/diagnostics/data/diagnostics_repository.dart';
import 'package:carcare_service/features/diagnostics/domain/diagnostic.dart';
import 'package:carcare_service/features/diagnostics/domain/diagnostics_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TemplateListScreen extends StatefulWidget {
  const TemplateListScreen({super.key, this.repo, this.user});
  final DiagnosticTemplateRepository? repo;
  final User? user;

  @override
  State<TemplateListScreen> createState() => _TemplateListScreenState();
}

class _TemplateListScreenState extends State<TemplateListScreen> {
  late final DiagnosticTemplateRepository _repo =
      widget.repo ?? DiagnosticsRepositoryImpl(RemoteDiagnosticsDataSource());
  bool _loading = true;
  String? _error;
  List<DiagnosticTemplateSummary> _templates = [];

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
    final result = await _repo.getTemplates();
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        _templates = value;
      case Err(:final error):
        _error = error.display;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _duplicate(DiagnosticTemplateSummary template) async {
    final result = await _repo.duplicateTemplate(template.id);
    if (!mounted) return;
    switch (result) {
      case Ok():
        messageComplete('Загварыг хууллаа');
        await _load();
      case Err(:final error):
        messageError(error.display);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user ?? Authenticator.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Оношилгооны загвар')),
      floatingActionButton: canSeeView(user, 'diagnostics.create')
          ? FloatingActionButton.extended(
              onPressed: () =>
                  context.push('${AppRoutes.diagnosticsTemplates}/new'),
              icon: const Icon(Icons.add),
              label: const Text('Шинэ загвар'),
            )
          : null,
      body: PermissionGate(
        permission: 'diagnostics.view',
        user: user,
        fallback: const EmptyState(
          message: 'Загвар үзэх эрх хүрэлцэхгүй байна.',
          icon: Icons.lock_outline,
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _Status(message: _error!, onTap: _load)
            : _templates.isEmpty
            ? const EmptyState(
                message: 'Оношилгооны загвар алга.',
                icon: Icons.description_outlined,
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  itemCount: _templates.length,
                  itemBuilder: (context, index) {
                    final template = _templates[index];
                    return ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(template.name),
                      subtitle: Text(
                        '${template.type.label} · v${template.version}${template.isActive ? '' : ' · Идэвхгүй'}',
                      ),
                      trailing: canSeeView(user, 'diagnostics.create')
                          ? PopupMenuButton<String>(
                              tooltip: 'Үйлдэл',
                              onSelected: (action) {
                                if (action == 'duplicate') {
                                  _duplicate(template);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'duplicate',
                                  child: Text('Хуулах'),
                                ),
                              ],
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: () => context.push(
                        '${AppRoutes.diagnosticsTemplates}/${template.id}',
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
  const _Status({required this.message, required this.onTap});
  final String message;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        TextButton(onPressed: onTap, child: const Text('Дахин оролдох')),
      ],
    ),
  );
}
