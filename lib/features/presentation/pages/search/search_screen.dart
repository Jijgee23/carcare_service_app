import 'dart:async';
import 'package:flutter/material.dart';
import 'package:carcare_service/core/theme/app_theme.dart';
import 'package:carcare_service/features/models/diagnostic.dart';
import 'package:carcare_service/core/services/diagnostic_service.dart';
import 'package:carcare_service/shared/widgets/common/common_widgets.dart';
import 'package:carcare_service/features/presentation/pages/search/customer_detail_screen.dart';
import 'package:carcare_service/features/presentation/pages/search/vehicle_detail_screen.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Хайлт'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.person_outline, size: 18), text: 'Үйлчлүүлэгч'),
              Tab(icon: Icon(Icons.directions_car_outlined, size: 18), text: 'Машин'),
            ],
          ),
        ),
        body: const TabBarView(children: [_CustomerSearchTab(), _VehicleSearchTab()]),
      ),
    );
  }
}

// ─── Customer search tab ──────────────────────────────────────────────────────

class _CustomerSearchTab extends StatefulWidget {
  const _CustomerSearchTab();

  @override
  State<_CustomerSearchTab> createState() => _CustomerSearchTabState();
}

class _CustomerSearchTabState extends State<_CustomerSearchTab> {
  final _ctrl = TextEditingController();
  List<CustomerSummary> _results = [];
  bool _loading = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _search(String q) {
    _timer?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    _timer = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _loading = true);
      final results = await DiagnosticService.searchCustomers(q.trim());
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _ctrl,
            onChanged: _search,
            decoration: InputDecoration(
              hintText: 'Нэр эсвэл утасны дугаараар хайх...',
              prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _ctrl.clear();
                        _search('');
                      },
                    )
                  : null,
            ),
            style: AppTextStyles.body,
          ),
        ),
        if (_ctrl.text.isNotEmpty && _results.isEmpty && !_loading)
          const Expanded(
            child: EmptyState(message: 'Үйлчлүүлэгч олдсонгүй', icon: Icons.person_search_outlined),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: _results.length,
              separatorBuilder: (context, i) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final c = _results[i];
                return _CustomerCard(
                  customer: c,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CustomerDetailScreen(customer: c)),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final CustomerSummary customer;
  final VoidCallback onTap;
  const _CustomerCard({required this.customer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.accent.withOpacity(0.12),
            child: Text(
              customer.displayName.isNotEmpty ? customer.displayName[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.displayName, style: AppTextStyles.bodyMedium),
                const SizedBox(height: 2),
                Text(customer.phone, style: AppTextStyles.caption),
                if (customer.email != null) Text(customer.email!, style: AppTextStyles.caption),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textHint),
        ],
      ),
    );
  }
}

// ─── Vehicle search tab ───────────────────────────────────────────────────────

class _VehicleSearchTab extends StatefulWidget {
  const _VehicleSearchTab();

  @override
  State<_VehicleSearchTab> createState() => _VehicleSearchTabState();
}

class _VehicleSearchTabState extends State<_VehicleSearchTab> {
  final _ctrl = TextEditingController();
  List<VehicleSummary> _results = [];
  bool _loading = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _search(String q) {
    _timer?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    _timer = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _loading = true);
      final results = await DiagnosticService.searchVehicles(q.trim());
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _ctrl,
            onChanged: _search,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Улсын дугаар эсвэл маркаар хайх...',
              prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _ctrl.clear();
                        _search('');
                      },
                    )
                  : null,
            ),
            style: AppTextStyles.body,
          ),
        ),
        if (_ctrl.text.isNotEmpty && _results.isEmpty && !_loading)
          const Expanded(
            child: EmptyState(message: 'Машин олдсонгүй', icon: Icons.no_crash_outlined),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: _results.length,
              separatorBuilder: (context, i) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final v = _results[i];
                return _VehicleCard(
                  vehicle: v,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicle: v)),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final VehicleSummary vehicle;
  final VoidCallback onTap;
  const _VehicleCard({required this.vehicle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppDimens.radiusMD),
            ),
            child: const Icon(Icons.directions_car_outlined, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vehicle.plate, style: AppTextStyles.bodyMedium),
                const SizedBox(height: 2),
                Text(vehicle.displayName, style: AppTextStyles.caption),
                if (vehicle.customer != null)
                  Text(
                    vehicle.customer!.displayName,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textHint),
        ],
      ),
    );
  }
}
