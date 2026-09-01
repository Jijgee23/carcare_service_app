import 'dart:async';

import 'package:carcare_service/core/theme/app_theme.dart';
import 'package:carcare_service/features/models/service_catalog.dart';
import 'package:carcare_service/features/presentation/pages/services/create_service_screen.dart';
import 'package:carcare_service/features/presentation/pages/services/labor_category_list_screen.dart';
import 'package:carcare_service/features/presentation/pages/services/service_detail_screen.dart';
import 'package:carcare_service/features/presentation/pages/services/unit_list_screen.dart';
import 'package:carcare_service/core/services/service_catalog_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ServiceListScreen extends StatefulWidget {
  const ServiceListScreen({super.key});

  @override
  State<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends State<ServiceListScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _searchCtrl = TextEditingController();
  String _query = '';
  Timer? _debounce;
  int _refreshKey = 0;

  final _numFmt = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Үйлчилгээний каталог'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune_rounded),
            onSelected: (v) {
              if (v == 'categories') {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const LaborCategoryListScreen()));
              } else if (v == 'units') {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const UnitListScreen()));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'categories',
                child: Row(children: [
                  Icon(Icons.category_outlined, size: 18),
                  SizedBox(width: 10),
                  Text('Ажлын ангилал'),
                ]),
              ),
              PopupMenuItem(
                value: 'units',
                child: Row(children: [
                  Icon(Icons.straighten_outlined, size: 18),
                  SizedBox(width: 10),
                  Text('Хэмжих нэгж'),
                ]),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearch,
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Нэр, код хайх...',
                      hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 18),
                      suffixIcon: _query.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                              child: const Icon(Icons.close, color: Colors.white54, size: 18),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.12),
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
                        borderSide: const BorderSide(color: Colors.white30),
                      ),
                    ),
                  ),
                ),
              ),
              // Tabs
              TabBar(
                controller: _tab,
                tabs: const [
                  Tab(text: 'Ажил'),
                  Tab(text: 'Сэлбэг/Бараа'),
                  Tab(text: 'Оношилгоо'),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'service_create_fab',
        onPressed: () async {
          final tabType = const [
            ServiceKind.LABOR,
            ServiceKind.GOODS,
            ServiceKind.DIAGNOSTIC,
          ][_tab.index];
          final created = await Navigator.push<CatalogService>(
            context,
            MaterialPageRoute(
                builder: (_) => CreateServiceScreen(initialType: tabType)),
          );
          if (created != null && mounted) {
            setState(() => _refreshKey++);
          }
        },
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _ServiceTab(
              key: ValueKey('LABOR-$_refreshKey'),
              type: 'LABOR',
              query: _query,
              numFmt: _numFmt),
          _ServiceTab(
              key: ValueKey('GOODS-$_refreshKey'),
              type: 'GOODS',
              query: _query,
              numFmt: _numFmt),
          _ServiceTab(
              key: ValueKey('DIAG-$_refreshKey'),
              type: 'DIAGNOSTIC',
              query: _query,
              numFmt: _numFmt),
        ],
      ),
    );
  }
}

// ─── Tab body ──────────────────────────────────────────────────────────────────

class _ServiceTab extends StatefulWidget {
  final String type;
  final String query;
  final NumberFormat numFmt;
  const _ServiceTab({super.key, required this.type, required this.query, required this.numFmt});

  @override
  State<_ServiceTab> createState() => _ServiceTabState();
}

class _ServiceTabState extends State<_ServiceTab> with AutomaticKeepAliveClientMixin {
  List<CatalogService> _items = [];
  bool _loading = true;
  String _loadedQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_ServiceTab old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await ServiceCatalogService.getServices(
      type: widget.type,
      q: widget.query.isEmpty ? null : widget.query,
    );
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
        _loadedQuery = widget.query;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.type == 'LABOR'
                  ? Icons.build_outlined
                  : widget.type == 'DIAGNOSTIC'
                      ? Icons.troubleshoot_outlined
                      : Icons.inventory_2_outlined,
              size: 56,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 12),
            Text(
              _loadedQuery.isNotEmpty
                  ? '"$_loadedQuery" — үр дүн олдсонгүй'
                  : 'Үйлчилгээ байхгүй байна',
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppDimens.paddingMD),
        itemCount: _items.length,
        separatorBuilder: (context, i) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _ServiceCard(
          service: _items[i],
          numFmt: widget.numFmt,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ServiceDetailScreen(serviceId: _items[i].id)),
          ),
        ),
      ),
    );
  }
}

// ─── Service card ──────────────────────────────────────────────────────────────

class _ServiceCard extends StatelessWidget {
  final CatalogService service;
  final NumberFormat numFmt;
  final VoidCallback onTap;
  const _ServiceCard({required this.service, required this.numFmt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = service;

    return Material(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(AppDimens.radiusLG),
      elevation: AppDimens.cardElevation,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusLG),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: s.type.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                ),
                child: Icon(s.type.icon, size: 22, color: s.type.color),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.name,
                            style: AppTextStyles.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!s.isActive)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.textHint.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                            ),
                            child: const Text(
                              'Идэвхгүй',
                              style: TextStyle(fontSize: 10, color: AppColors.textHint),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (s.laborCategory != null) ...[
                          const Icon(Icons.folder_outlined, size: 12, color: AppColors.textHint),
                          const SizedBox(width: 3),
                          Text(s.laborCategory!.name, style: AppTextStyles.caption),
                          const SizedBox(width: 10),
                        ],
                        if (s.code != null) ...[
                          const Icon(Icons.tag, size: 12, color: AppColors.textHint),
                          const SizedBox(width: 2),
                          Text(s.code!, style: AppTextStyles.caption),
                        ],
                        if (s.type == ServiceKind.GOODS) ...[
                          const SizedBox(width: 6),
                          _StockBadge(level: s.stockLevel, display: s.stockDisplay),
                        ],
                      ],
                    ),
                    if (s.type != ServiceKind.GOODS && s.durationValue != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.schedule_outlined, size: 12, color: AppColors.textHint),
                          const SizedBox(width: 3),
                          Text(s.durationDisplay, style: AppTextStyles.caption),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Price
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${numFmt.format(s.price.toInt())}₮',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (s.unit != null) Text('/ ${s.unit!.display}', style: AppTextStyles.caption),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}


class _StockBadge extends StatelessWidget {
  final StockLevel level;
  final String display;
  const _StockBadge({required this.level, required this.display});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: level.bgColor,
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: level.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            display,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: level.color),
          ),
        ],
      ),
    );
  }
}
