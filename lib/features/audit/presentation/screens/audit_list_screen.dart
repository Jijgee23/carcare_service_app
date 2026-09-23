import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/widgets/adaptive/async_state_view.dart';
import 'package:carcare_service/core/widgets/adaptive/permission_gate.dart';
import 'package:carcare_service/core/widgets/common/common_widgets.dart';
import 'package:carcare_service/core/widgets/mixin/pagination_mixin.dart';
import 'package:carcare_service/features/audit/domain/audit_log.dart';
import 'package:carcare_service/features/audit/domain/audit_repository.dart';
import 'package:carcare_service/features/audit/presentation/controllers/audit_list_controller.dart';
import 'package:carcare_service/features/audit/presentation/widgets/audit_entry_detail_sheet.dart';
import 'package:carcare_service/features/audit/presentation/widgets/audit_filter_sheet.dart';
import 'package:carcare_service/features/audit/presentation/widgets/audit_vocab.dart';

/// Server-paginated Audit log — P7-F3. Page size is fixed at 50 server-side.
///
/// Gated on `audit.view` at the surface level (matching the web's
/// `hasPermission(me, "audit.view")` redirect and every other list screen in
/// this app's D-163 precedent).
///
/// **Not wired to a route** — `lib/app/router.dart` is owned by `P7-F4`.
/// Intended route: `/audit`.
class AuditListScreen extends StatelessWidget {
  const AuditListScreen({super.key, this.repository, this.user});

  final AuditRepository? repository;
  final User? user;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => AuditListController(repo: repository),
    child: _Body(user: user),
  );
}

class _Body extends StatefulWidget {
  const _Body({this.user});
  final User? user;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> with PaginationMixin {
  final _searchController = TextEditingController();
  bool _didLoad = false;

  User? get _user => widget.user ?? Authenticator.user;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoad) {
      _didLoad = true;
      final controller = context.read<AuditListController>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        initPagination(() {
          if (mounted) controller.loadMore();
        });
        controller.loadAuditLog();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openFilters(AuditListController controller) async {
    final result = await AuditFilterSheet.show(
      context,
      meta: controller.meta,
      action: controller.action,
      entity: controller.entity,
      userId: controller.userId,
      from: controller.from,
      to: controller.to,
    );
    if (result == null || !mounted) return;
    controller.applyFilters(
      action: result.action,
      entity: result.entity,
      userId: result.userId,
      from: result.from,
      to: result.to,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (!canSeeView(user, 'audit.view')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Аудит лог')),
        body: const EmptyState(
          message: 'Танд аудит лог харах эрх байхгүй байна.',
          icon: Icons.lock_outline,
        ),
      );
    }

    final controller = context.watch<AuditListController>();
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Аудит лог'),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () => _openFilters(controller),
                icon: const Icon(Icons.filter_list),
                tooltip: 'Шүүлтүүр',
              ),
              if (controller.hasActiveFilters)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: context.colors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: controller.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _SearchField(
              controller: _searchController,
              onChanged: controller.setQuery,
              onClear: () {
                _searchController.clear();
                controller.setQuery('');
              },
            ),
          ),
        ),
      ),
      body: AsyncStateView<List<AuditLogEntry>>(
        state: controller.listState,
        isEmpty: (items) => items.isEmpty,
        empty: _EmptyView(query: controller.query),
        onRetry: controller.refresh,
        builder: (context, items) {
          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.all(AppDimens.paddingMD),
              itemCount: items.length + 1,
              separatorBuilder: (_, i) =>
                  SizedBox(height: i == items.length - 1 ? 4 : 8),
              itemBuilder: (_, index) {
                if (index == items.length) {
                  return _ListFooter(controller: controller);
                }
                final entry = items[index];
                return _AuditCard(
                  entry: entry,
                  onTap: () => AuditEntryDetailSheet.show(context, entry),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ─── Search ─────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(fontSize: 14, color: context.colors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Тайлбар, обьектын ID-аар хайх...',
        hintStyle: TextStyle(color: context.colors.textHint, fontSize: 14),
        prefixIcon: Icon(Icons.search, color: context.colors.textHint, size: 18),
        suffixIcon: controller.text.isEmpty
            ? null
            : GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, color: context.colors.textHint, size: 18),
              ),
        filled: true,
        fillColor: context.colors.background,
        contentPadding: EdgeInsets.zero,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
          borderSide: BorderSide(color: CarCareTheme.of(context).accentHi),
        ),
      ),
    ),
  );
}

// ─── Empty / footer ──────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.receipt_long_outlined, size: 56, color: context.colors.textHint),
        const SizedBox(height: 12),
        Text(
          query.isNotEmpty ? '"$query" — үр дүн олдсонгүй' : 'Аудит бичлэг олдсонгүй',
          style: context.textStyles.body.copyWith(color: context.colors.textSecondary),
        ),
      ],
    ),
  );
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.controller});
  final AuditListController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final loadMoreError = controller.loadMoreError;
    if (loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: TextButton.icon(
          onPressed: controller.loadMore,
          icon: const Icon(Icons.refresh),
          label: Text('Дахин оролдох: ${loadMoreError.display}'),
        ),
      );
    }
    if (controller.hasNext) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: TextButton.icon(
          onPressed: controller.loadMore,
          icon: const Icon(Icons.expand_more),
          label: const Text('Дараагийн хуудас'),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text('Нийт ${controller.total} бичлэг', style: context.textStyles.caption),
      ),
    );
  }
}

// ─── Row card ─────────────────────────────────────────────────────────────

class _AuditCard extends StatelessWidget {
  const _AuditCard({required this.entry, required this.onTap});

  final AuditLogEntry entry;
  final VoidCallback onTap;

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final e = entry;
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(AppDimens.radiusLG),
      elevation: AppDimens.cardElevation,
      shadowColor: context.colors.textPrimary.withOpacity(0.12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusLG),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      e.summary ?? (e.action == null ? 'Аудит бичлэг' : auditActionLabel(e.action!)),
                      style: context.textStyles.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: context.colors.textHint),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (e.action != null) _MiniBadge(text: auditActionLabel(e.action!)),
                  if (e.entity != null) _MiniBadge(text: auditEntityLabel(e.entity!)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${e.user?.displayName ?? 'Систем'} · ${_fmtDate(e.createdAt)}',
                style: context.textStyles.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: context.colors.accent.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(AppDimens.radiusFull),
    ),
    child: Text(text, style: TextStyle(fontSize: 10, color: context.colors.accent)),
  );
}
