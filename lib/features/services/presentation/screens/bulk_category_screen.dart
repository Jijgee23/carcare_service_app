import 'package:flutter/material.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/core/widgets/adaptive/permission_gate.dart';
import 'package:carcare_service/core/widgets/common/common_widgets.dart';
import 'package:carcare_service/core/widgets/dialogs/message.dart';
import 'package:carcare_service/core/widgets/picker_screen.dart';
import 'package:carcare_service/features/services/data/service_repository.dart';
import 'package:carcare_service/features/services/domain/service.dart';
import 'package:carcare_service/features/services/domain/services_repository.dart';

/// Bulk category re-assignment — P4-F3, new surface.
///
/// `POST /services/bulk/category` is per-item, explicitly **not**
/// all-or-nothing (`BulkCategoryResult`'s doc comment) — the opposite of the
/// Orders/Appointments bulk pattern this screen otherwise copies the
/// touch-native checkbox-row + bottom action-bar affordance from
/// (`order_list_screen.dart`'s `BulkSelectionBar`/`_BulkFailureBanner`). A
/// missing/unknown category id, or an empty selection, is a **whole-request**
/// rejection (`CATEGORY_REQUIRED`/`CATEGORY_NOT_FOUND`/`EMPTY_SELECTION`) and
/// is surfaced as a toast, never folded into the per-item result — see the
/// class doc comment on [ServicesRepository.bulkChangeCategory].
///
/// Gated on `services.edit` — the same permission the backend requires on
/// this route (`P4-B1`) — at the surface level (D-163), not only on the
/// submit button.
///
/// Not yet wired to a navigation entry point: `service_list_screen.dart` is
/// owned by the concurrent `P4-F2` slice and this slice may not touch it.
/// This screen is a complete, self-contained destination
/// (`Navigator.push(MaterialPageRoute(builder: (_) =>
/// const BulkCategoryScreen()))`) ready for whichever slice adds the button —
/// `P4-F2` or `P4-F4`.
class BulkCategoryScreen extends StatefulWidget {
  const BulkCategoryScreen({super.key, this.repo, this.user});

  final ServicesRepository? repo;
  final User? user;

  @override
  State<BulkCategoryScreen> createState() => _BulkCategoryScreenState();
}

class _BulkCategoryScreenState extends State<BulkCategoryScreen> {
  late final ServicesRepository _repo =
      widget.repo ?? RemoteServicesRepository();
  User? get _user => widget.user ?? Authenticator.user;

  bool _loading = true;
  AppError? _loadError;
  List<Service> _items = const [];
  List<Category> _categories = const [];
  ServiceKind? _typeFilter;
  final Set<String> _selected = {};

  bool _submitting = false;
  BulkCategoryResult? _lastResult;

  bool get _canEdit => canSeeView(_user, 'services.edit');

  @override
  void initState() {
    super.initState();
    if (_canEdit) _load();
  }

  /// Loads every page up to a defensive cap (1,000 rows across 10 pages of
  /// 100) rather than one page — a bulk-selection surface that silently
  /// truncated the catalogue would misinform staff about what "select all"
  /// actually covers.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final categoriesResult = await _repo.getCategories();

    final items = <Service>[];
    AppError? loadError;
    const pageSize = 100;
    const maxPages = 10; // defensive cap — 1,000 rows
    for (var page = 1; page <= maxPages; page++) {
      final result = await _repo.getServices(
        query: ServiceListQuery(page: page, pageSize: pageSize),
      );
      if (result case Ok(:final value)) {
        items.addAll(value.items);
        if (!value.pagination.hasNext) break;
      } else if (result case Err(:final error)) {
        loadError = error;
        break;
      }
    }
    if (categoriesResult case Err(:final error) when loadError == null) {
      loadError = error;
    }

    if (!mounted) return;
    setState(() {
      _items = items;
      _categories = switch (categoriesResult) {
        Ok(:final value) => value,
        Err() => const [],
      };
      _loadError = loadError;
      _loading = false;
      _selected.removeWhere((id) => !items.any((s) => s.id == id));
    });
  }

  List<Service> get _visible => _typeFilter == null
      ? _items
      : _items.where((s) => s.type == _typeFilter).toList(growable: false);

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
      _lastResult = null;
    });
  }

  void _toggleAllVisible() {
    final visibleIds = _visible.map((s) => s.id).toSet();
    final allSelected = visibleIds.every(_selected.contains);
    setState(() {
      if (allSelected) {
        _selected.removeAll(visibleIds);
      } else {
        _selected.addAll(visibleIds);
      }
      _lastResult = null;
    });
  }

  Future<void> _pickCategoryAndApply() async {
    if (_selected.isEmpty || _categories.isEmpty) return;
    final picked = await PickerScreen.push<Category>(
      context,
      title: 'Шинэ ангилал',
      items: _categories,
      label: (c) => c.name ?? 'Нэргүй',
    );
    if (picked == null || !mounted) return;

    setState(() => _submitting = true);
    final result = await _repo.bulkChangeCategory(
      serviceIds: _selected.toList(growable: false),
      categoryId: picked.id,
    );
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        setState(() {
          _submitting = false;
          _lastResult = value;
          _selected.clear();
        });
        await _load();
      case Err(:final error):
        setState(() => _submitting = false);
        // Whole-request rejection — never per-item, see the class doc
        // comment — so a toast is the right surface here, unlike the
        // per-item errors rendered in `_lastResult`.
        messageError(error.display);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canEdit) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ангилал бөөнөөр солих')),
        body: const EmptyState(
          message: 'Энэ үйлдэлд эрх байхгүй байна',
          icon: Icons.lock_outline,
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Ангилал бөөнөөр солих'),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: 'Бүгдийг сонгох/цуцлах',
            onPressed: _visible.isEmpty ? null : _toggleAllVisible,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Бүгд',
                  selected: _typeFilter == null,
                  onTap: () => setState(() => _typeFilter = null),
                ),
                const SizedBox(width: 6),
                for (final kind in const [
                  ServiceKind.labor,
                  ServiceKind.goods,
                  ServiceKind.diagnostic,
                ]) ...[
                  _FilterChip(
                    label: kind.label,
                    selected: _typeFilter == kind,
                    onTap: () => setState(() => _typeFilter = kind),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _selected.isEmpty
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Material(
                  color: context.colors.surface,
                  elevation: 4,
                  borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${_selected.length} сонгосон',
                          style: context.textStyles.bodyMedium,
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          key: const ValueKey('bulk_category_apply'),
                          onPressed: _submitting || _categories.isEmpty
                              ? null
                              : _pickCategoryAndApply,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.folder_outlined, size: 18),
                          label: const Text('Ангилал солих'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null && _items.isEmpty) {
      return ErrorStateView(message: _loadError!.display, onRetry: _load);
    }
    final visible = _visible;
    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          if (_lastResult != null) _BulkResultBanner(result: _lastResult!),
          Expanded(
            child: visible.isEmpty
                ? const EmptyState(
                    message: 'Үйлчилгээ байхгүй байна',
                    icon: Icons.inventory_2_outlined,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppDimens.paddingMD),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, i) {
                      final service = visible[i];
                      final selected = _selected.contains(service.id);
                      return _SelectableServiceRow(
                        service: service,
                        selected: selected,
                        onTap: () => _toggle(service.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? context.colors.accent.withValues(alpha: 0.14)
              : null,
          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
          border: Border.all(
            color: selected ? context.colors.accent : context.colors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected
                ? context.colors.accent
                : context.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _SelectableServiceRow extends StatelessWidget {
  const _SelectableServiceRow({
    required this.service,
    required this.selected,
    required this.onTap,
  });

  final Service service;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(AppDimens.radiusMD),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusMD),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            children: [
              Checkbox(value: selected, onChanged: (_) => onTap()),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.displayName,
                      style: context.textStyles.bodyMedium,
                    ),
                    if (service.category?.name != null)
                      Text(
                        service.category!.name!,
                        style: context.textStyles.caption,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BulkResultBanner extends StatelessWidget {
  const _BulkResultBanner({required this.result});

  final BulkCategoryResult result;

  @override
  Widget build(BuildContext context) {
    final hasFailures = result.failed > 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDimens.paddingMD,
        AppDimens.paddingMD,
        AppDimens.paddingMD,
        0,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasFailures ? context.colors.dangerBg : context.colors.goodBg,
        borderRadius: BorderRadius.circular(AppDimens.radiusMD),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${result.succeeded} амжилттай, ${result.failed} амжилтгүй',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: hasFailures ? context.colors.danger : context.colors.good,
            ),
          ),
          if (result.errors.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...result.errors.map(
              (e) => Text(
                '• $e',
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
