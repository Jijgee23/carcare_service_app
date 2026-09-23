import 'dart:async';

import 'package:flutter/material.dart';
import 'package:carcare_service/features/orders/presentation/feature_theme.dart';
import 'package:intl/intl.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/domain/diagnostic.dart';
import 'package:carcare_service/features/orders/domain/order.dart';
import 'package:carcare_service/features/orders/presentation/screens/new_customer_sheet.dart';
import 'package:carcare_service/features/orders/presentation/screens/new_vehicle_screen.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/core/services/diagnostic_service.dart';
import 'package:carcare_service/features/orders/domain/orders_repository.dart';
import 'package:carcare_service/core/widgets/dialogs/message.dart';
import 'package:carcare_service/core/widgets/mn_date_picker.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key, required this.repository});

  final OrdersRepository repository;

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  // Vehicle search
  final _plateCtrl = TextEditingController();
  List<VehicleSummary> _vehicleResults = [];
  bool _searchingVehicle = false;
  VehicleSummary? _vehicle;
  CustomerSummary? _customer;
  Timer? _vehicleTimer;

  // Branch + schedule + notes
  List<BranchSummary> _branches = [];
  BranchSummary? _branch;
  DateTime? _scheduledAt;
  int? _estimatedDurationMinutes;
  final _notesCtrl = TextEditingController();
  bool _submitting = false;

  final _dateFmt = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _loadBranches();
    _notesCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _vehicleTimer?.cancel();
    _plateCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    final branches = await DiagnosticService.getBranches();
    if (!mounted) return;
    final branchId = Authenticator.user?.branchId;
    setState(() {
      _branches = branches;
      if (branchId != null) {
        try {
          _branch = branches.firstWhere((b) => b.id == branchId);
        } catch (_) {
          _branch = branches.isNotEmpty ? branches.first : null;
        }
      } else if (branches.isNotEmpty) {
        _branch = branches.first;
      }
    });
  }

  void _searchVehicle(String q) {
    _vehicleTimer?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _vehicleResults = []);
      return;
    }
    _vehicleTimer = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _searchingVehicle = true);
      final results = await DiagnosticService.searchVehicles(q.trim());
      if (!mounted) return;
      setState(() {
        _vehicleResults = results;
        _searchingVehicle = false;
      });
    });
  }

  void _selectVehicle(VehicleSummary v) {
    setState(() {
      _vehicle = v;
      _customer = v.customer;
      _vehicleResults = [];
      _plateCtrl.clear();
    });
  }

  void _clearVehicle() => setState(() {
    _vehicle = null;
    _customer = null;
  });

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final result = await showMnDateTimePicker(
      context,
      initial: _scheduledAt ?? DateTime(now.year, now.month, now.day, 9, 0),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (result != null && mounted) setState(() => _scheduledAt = result);
  }

  // Controller-free dialog: a short-lived TextEditingController disposed
  // while the dialog's exit transition still referenced it produced
  // "A TextEditingController was used after being disposed" (fixed
  // elsewhere in this repo — see the status-change duration dialog in
  // order_detail_screen.dart). Capture input in a plain local instead.
  Future<void> _pickDuration() async {
    var input = _estimatedDurationMinutes?.toString() ?? '';
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ажлын хугацаа'),
        content: TextFormField(
          key: const ValueKey('create_order_duration_input'),
          initialValue: input,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Минут'),
          onChanged: (value) => input = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Болих'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(input.trim());
              if (parsed != null && parsed > 0) {
                Navigator.pop(dialogContext, parsed);
              }
            },
            child: const Text('Сонгох'),
          ),
        ],
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _estimatedDurationMinutes = result);
  }

  Future<void> _openNewVehicle() async {
    final plate = _plateCtrl.text.trim();
    final result = await Navigator.push<NewVehicleResult>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            NewVehicleScreen(initialPlate: plate.isEmpty ? null : plate),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _vehicle = result.vehicle;
        _customer = result.customer ?? result.vehicle.customer;
        _vehicleResults = [];
        _plateCtrl.clear();
      });
    }
  }

  Future<void> _openAddCustomer() async {
    final result = await showNewCustomerSheet(context);
    if (result != null && mounted) setState(() => _customer = result);
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final customerId = _customer?.id ?? _vehicle!.customerId;
    setState(() => _submitting = true);
    final result = await widget.repository.createOrder(
      branchId: _branch!.id,
      customerId: customerId!,
      vehicleId: _vehicle!.id,
      scheduledAt: _scheduledAt,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      estimatedDurationMinutes: _estimatedDurationMinutes,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    switch (result) {
      case Ok(:final value):
        Navigator.pop(context, value);
      case Err(:final error):
        messageError(error.display);
    }
  }

  bool get _canSubmit =>
      _vehicle != null &&
      _branch != null &&
      (_customer != null || _vehicle?.customerId != null);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.opsBackground,
      appBar: AppBar(title: Text('Захиалга үүсгэх')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 1. Машин ───────────────────────────────────────────
                  _SectionLabel(
                    number: '1',
                    title: 'Машин сонгох',
                    done: _vehicle != null,
                  ),
                  const SizedBox(height: 10),
                  _VehicleSection(
                    ctrl: _plateCtrl,
                    searching: _searchingVehicle,
                    results: _vehicleResults,
                    selected: _vehicle,
                    customer: _customer,
                    onSearch: _searchVehicle,
                    onSelect: _selectVehicle,
                    onClear: _clearVehicle,
                    onNewVehicle: _openNewVehicle,
                    onAddCustomer: _openAddCustomer,
                  ),
                  const SizedBox(height: 24),

                  // ── 2. Салбар ──────────────────────────────────────────
                  _SectionLabel(
                    number: '2',
                    title: 'Салбар',
                    done: _branch != null,
                  ),
                  const SizedBox(height: 10),
                  _BranchSection(
                    branches: _branches,
                    selected: _branch,
                    onSelect: (b) => setState(() => _branch = b),
                  ),
                  const SizedBox(height: 24),

                  // ── 3. Нэмэлт ──────────────────────────────────────────
                  _SectionLabel(
                    number: '3',
                    title: 'Нэмэлт мэдээлэл',
                    done: _scheduledAt != null || _notesCtrl.text.isNotEmpty,
                    optional: true,
                  ),
                  const SizedBox(height: 10),
                  _DetailsSection(
                    scheduledAt: _scheduledAt,
                    notesCtrl: _notesCtrl,
                    dateFmt: _dateFmt,
                    onPickDate: _pickSchedule,
                    onClearDate: () => setState(() => _scheduledAt = null),
                    estimatedDurationMinutes: _estimatedDurationMinutes,
                    onPickDuration: _pickDuration,
                    onClearDuration: () =>
                        setState(() => _estimatedDurationMinutes = null),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // ── Sticky bottom bar ─────────────────────────────────────────
          _BottomBar(
            vehicle: _vehicle,
            branch: _branch,
            scheduledAt: _scheduledAt,
            dateFmt: _dateFmt,
            canSubmit: _canSubmit,
            submitting: _submitting,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}

// ─── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String number;
  final String title;
  final bool done;
  final bool optional;
  const _SectionLabel({
    required this.number,
    required this.title,
    this.done = false,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: done ? context.opsGood : context.opsPrimary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: done
                ? Icon(
                    Icons.check_rounded,
                    size: 13,
                    color: context.opsTextOnDark,
                  )
                : Text(
                    number,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: context.opsTextOnDark,
                    ),
                  ),
          ),
        ),
        SizedBox(width: 8),
        Text(
          title,
          style: context.textStyles.h3.copyWith(
            color: done ? context.opsGood : context.opsTextPrimary,
          ),
        ),
        if (optional) ...[
          SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: context.opsBackground,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'заавал биш',
              style: TextStyle(fontSize: 10, color: context.opsTextHint),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Vehicle section ───────────────────────────────────────────────────────────

class _VehicleSection extends StatelessWidget {
  final TextEditingController ctrl;
  final bool searching;
  final List<VehicleSummary> results;
  final VehicleSummary? selected;
  final CustomerSummary? customer;
  final ValueChanged<String> onSearch;
  final ValueChanged<VehicleSummary> onSelect;
  final VoidCallback onClear;
  final VoidCallback onNewVehicle;
  final VoidCallback onAddCustomer;

  const _VehicleSection({
    required this.ctrl,
    required this.searching,
    required this.results,
    required this.selected,
    required this.customer,
    required this.onSearch,
    required this.onSelect,
    required this.onClear,
    required this.onNewVehicle,
    required this.onAddCustomer,
  });

  @override
  Widget build(BuildContext context) {
    if (selected != null) {
      final resolvedCustomer = customer ?? selected!.customer;
      return Column(
        children: [
          _SelectedVehicleCard(
            vehicle: selected!,
            customer: resolvedCustomer,
            onClear: onClear,
          ),
          // No customer warning + add button
          if (resolvedCustomer == null) ...[
            SizedBox(height: 8),
            GestureDetector(
              onTap: onAddCustomer,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: context.opsWarning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                  border: Border.all(
                    color: context.opsWarning.withOpacity(0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: context.opsWarning,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Эзэмшигч холбогдоогүй байна. Нэмэхийн тулд энд дарна уу.',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.opsWarning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: context.opsWarning,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      children: [
        // Search field
        Container(
          decoration: BoxDecoration(
            color: context.opsSurface,
            borderRadius: BorderRadius.circular(AppDimens.radiusMD),
            border: Border.all(color: context.opsDivider),
            boxShadow: [
              BoxShadow(
                color: context.opsTextPrimary.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: ctrl,
            textCapitalization: TextCapitalization.characters,
            onChanged: onSearch,
            style: context.textStyles.body,
            decoration: InputDecoration(
              hintText: 'Улсын дугаараар хайх...',
              prefixIcon: Icon(
                Icons.search_rounded,
                color: context.opsTextHint,
                size: 20,
              ),
              suffixIcon: searching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: context.opsTextHint,
                      ),
                      onPressed: () {
                        ctrl.clear();
                        onSearch('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: context.opsSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                borderSide: BorderSide(color: context.opsAccent, width: 1.5),
              ),
            ),
          ),
        ),

        // Search results
        if (results.isNotEmpty) ...[
          SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: context.opsSurface,
              borderRadius: BorderRadius.circular(AppDimens.radiusMD),
              border: Border.all(color: context.opsDivider),
              boxShadow: [
                BoxShadow(
                  color: context.opsTextPrimary.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: results.take(5).toList().asMap().entries.map((entry) {
                final i = entry.key;
                final v = entry.value;
                return InkWell(
                  onTap: () => onSelect(v),
                  borderRadius: BorderRadius.vertical(
                    top: i == 0
                        ? const Radius.circular(AppDimens.radiusMD)
                        : Radius.zero,
                    bottom: i == results.length - 1 || i == 4
                        ? const Radius.circular(AppDimens.radiusMD)
                        : Radius.zero,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      border: i < results.length - 1 && i < 4
                          ? Border(
                              bottom: BorderSide(color: context.opsDivider),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: context.opsAccent.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusSM,
                            ),
                          ),
                          child: Icon(
                            Icons.directions_car_outlined,
                            color: context.opsAccent,
                            size: 18,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                v.plate,
                                style: context.textStyles.bodyMedium,
                              ),
                              Text(
                                v.displayName,
                                style: context.textStyles.caption,
                              ),
                              if (v.customer != null)
                                Text(
                                  v.customer!.displayName,
                                  style: context.textStyles.caption.copyWith(
                                    color: context.opsTextHint,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: context.opsTextHint,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        // "New vehicle" button — always visible when no vehicle selected
        SizedBox(height: 10),
        GestureDetector(
          onTap: onNewVehicle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: context.opsSurface,
              borderRadius: BorderRadius.circular(AppDimens.radiusMD),
              border: Border.all(color: context.opsAccent.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  size: 18,
                  color: context.opsAccent,
                ),
                SizedBox(width: 10),
                Text(
                  'Шинэ машин бүртгэх',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.opsAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectedVehicleCard extends StatelessWidget {
  final VehicleSummary vehicle;
  final CustomerSummary? customer;
  final VoidCallback onClear;
  const _SelectedVehicleCard({
    required this.vehicle,
    required this.customer,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.opsSurface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMD),
        border: Border.all(
          color: context.opsAccent.withOpacity(0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: context.opsAccent.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: context.opsAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDimens.radiusMD),
            ),
            child: Icon(
              Icons.directions_car_rounded,
              color: context.opsAccent,
              size: 24,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.plate,
                  style: context.textStyles.h3.copyWith(
                    color: context.opsAccent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(vehicle.displayName, style: context.textStyles.caption),
                if (customer != null) ...[
                  SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 12,
                        color: context.opsTextHint,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        customer!.displayName,
                        style: context.textStyles.caption,
                      ),
                      SizedBox(width: 8),
                      Text(
                        customer!.phone,
                        style: context.textStyles.caption.copyWith(
                          color: context.opsTextHint,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: onClear,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: context.opsBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                size: 16,
                color: context.opsTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Branch section ────────────────────────────────────────────────────────────

class _BranchSection extends StatelessWidget {
  final List<BranchSummary> branches;
  final BranchSummary? selected;
  final ValueChanged<BranchSummary> onSelect;
  const _BranchSection({
    required this.branches,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // Loading
    if (branches.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.opsSurface,
          borderRadius: BorderRadius.circular(AppDimens.radiusMD),
          border: Border.all(color: context.opsDivider),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              'Салбаруудыг ачааллаж байна...',
              style: context.textStyles.caption,
            ),
          ],
        ),
      );
    }

    // Single branch — show as a read-only selected card
    if (branches.length == 1) {
      final b = branches.first;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.opsSurface,
          borderRadius: BorderRadius.circular(AppDimens.radiusMD),
          border: Border.all(color: context.opsGood.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(
              color: context.opsGood.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: context.opsGood.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppDimens.radiusSM),
              ),
              child: Icon(
                Icons.storefront_rounded,
                color: context.opsGood,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.name, style: context.textStyles.bodyMedium),
                  if (b.address != null)
                    Text(b.address!, style: context.textStyles.caption),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: context.opsGood.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppDimens.radiusFull),
              ),
              child: Text(
                'Автомат',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: context.opsGood,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Multi-branch — radio list
    return Container(
      decoration: BoxDecoration(
        color: context.opsSurface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMD),
        border: Border.all(color: context.opsDivider),
        boxShadow: [
          BoxShadow(
            color: context.opsTextPrimary.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: branches.asMap().entries.map((entry) {
          final i = entry.key;
          final b = entry.value;
          final isSelected = b.id == selected?.id;

          return InkWell(
            onTap: () => onSelect(b),
            borderRadius: BorderRadius.vertical(
              top: i == 0
                  ? const Radius.circular(AppDimens.radiusMD)
                  : Radius.zero,
              bottom: i == branches.length - 1
                  ? const Radius.circular(AppDimens.radiusMD)
                  : Radius.zero,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? context.opsAccent.withOpacity(0.06)
                    : Colors.transparent,
                borderRadius: BorderRadius.vertical(
                  top: i == 0
                      ? const Radius.circular(AppDimens.radiusMD)
                      : Radius.zero,
                  bottom: i == branches.length - 1
                      ? const Radius.circular(AppDimens.radiusMD)
                      : Radius.zero,
                ),
                border: i < branches.length - 1
                    ? Border(bottom: BorderSide(color: context.opsDivider))
                    : null,
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? context.opsAccent
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? context.opsAccent
                            : context.opsDivider,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            size: 12,
                            color: context.opsTextOnDark,
                          )
                        : null,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.name,
                          style: context.textStyles.bodyMedium.copyWith(
                            color: isSelected
                                ? context.opsAccent
                                : context.opsTextPrimary,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                        if (b.address != null)
                          Text(b.address!, style: context.textStyles.caption),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: context.opsAccent,
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Details section ───────────────────────────────────────────────────────────

class _DetailsSection extends StatelessWidget {
  final DateTime? scheduledAt;
  final TextEditingController notesCtrl;
  final DateFormat dateFmt;
  final VoidCallback onPickDate;
  final VoidCallback onClearDate;
  final int? estimatedDurationMinutes;
  final VoidCallback onPickDuration;
  final VoidCallback onClearDuration;
  const _DetailsSection({
    required this.scheduledAt,
    required this.notesCtrl,
    required this.dateFmt,
    required this.onPickDate,
    required this.onClearDate,
    required this.estimatedDurationMinutes,
    required this.onPickDuration,
    required this.onClearDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.opsSurface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMD),
        border: Border.all(color: context.opsDivider),
        boxShadow: [
          BoxShadow(
            color: context.opsTextPrimary.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Schedule row
          InkWell(
            onTap: onPickDate,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimens.radiusMD),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: scheduledAt != null
                          ? context.opsAccent.withOpacity(0.1)
                          : context.opsBackground,
                      borderRadius: BorderRadius.circular(AppDimens.radiusSM),
                    ),
                    child: Icon(
                      Icons.event_rounded,
                      size: 18,
                      color: scheduledAt != null
                          ? context.opsAccent
                          : context.opsTextHint,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Товлосон цаг',
                          style: context.textStyles.caption.copyWith(
                            color: scheduledAt != null
                                ? context.opsAccent
                                : context.opsTextSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          scheduledAt != null
                              ? dateFmt.format(scheduledAt!)
                              : 'Огноо, цаг сонгоно уу',
                          style: context.textStyles.body.copyWith(
                            color: scheduledAt != null
                                ? context.opsTextPrimary
                                : context.opsTextHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (scheduledAt != null)
                    GestureDetector(
                      onTap: onClearDate,
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: context.opsTextHint,
                      ),
                    )
                  else
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: context.opsTextHint,
                    ),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // Estimated duration row
          InkWell(
            key: const ValueKey('create_order_duration_row'),
            onTap: onPickDuration,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: estimatedDurationMinutes != null
                          ? context.opsAccent.withOpacity(0.1)
                          : context.opsBackground,
                      borderRadius: BorderRadius.circular(AppDimens.radiusSM),
                    ),
                    child: Icon(
                      Icons.timer_outlined,
                      size: 18,
                      color: estimatedDurationMinutes != null
                          ? context.opsAccent
                          : context.opsTextHint,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ажлын хугацаа',
                          style: context.textStyles.caption.copyWith(
                            color: estimatedDurationMinutes != null
                                ? context.opsAccent
                                : context.opsTextSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          estimatedDurationMinutes != null
                              ? '$estimatedDurationMinutes мин'
                              : 'Хугацаа сонгоно уу',
                          style: context.textStyles.body.copyWith(
                            color: estimatedDurationMinutes != null
                                ? context.opsTextPrimary
                                : context.opsTextHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (estimatedDurationMinutes != null)
                    GestureDetector(
                      onTap: onClearDuration,
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: context.opsTextHint,
                      ),
                    )
                  else
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: context.opsTextHint,
                    ),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // Notes
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: context.opsBackground,
                      borderRadius: BorderRadius.circular(AppDimens.radiusSM),
                    ),
                    child: Icon(
                      Icons.notes_rounded,
                      size: 18,
                      color: context.opsTextHint,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: notesCtrl,
                    maxLines: 3,
                    style: context.textStyles.body,
                    decoration: const InputDecoration(
                      hintText: 'Тэмдэглэл... (заавал биш)',
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sticky bottom bar ─────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final VehicleSummary? vehicle;
  final BranchSummary? branch;
  final DateTime? scheduledAt;
  final DateFormat dateFmt;
  final bool canSubmit;
  final bool submitting;
  final VoidCallback onSubmit;

  const _BottomBar({
    required this.vehicle,
    required this.branch,
    required this.scheduledAt,
    required this.dateFmt,
    required this.canSubmit,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    // Determine what's missing
    final String? missingHint = vehicle == null
        ? 'Машин сонгоогүй байна'
        : branch == null
        ? 'Салбар сонгоогүй байна'
        : null;

    return Container(
      decoration: BoxDecoration(
        color: context.opsSurface,
        border: Border(top: BorderSide(color: context.opsDivider)),
        boxShadow: [
          BoxShadow(
            color: context.opsTextPrimary.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Summary row when ready
          if (canSubmit) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.opsBackground,
                borderRadius: BorderRadius.circular(AppDimens.radiusSM),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.directions_car_outlined,
                    size: 13,
                    color: context.opsTextSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(vehicle!.plate, style: context.textStyles.captionMedium),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      '· ${vehicle!.displayName}',
                      style: context.textStyles.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (scheduledAt != null) ...[
                    SizedBox(width: 6),
                    Icon(
                      Icons.event_outlined,
                      size: 13,
                      color: context.opsTextSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dateFmt.format(scheduledAt!),
                      style: context.textStyles.caption,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Requirements hint when not ready
          if (missingHint != null) ...[
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 13,
                  color: context.opsWarning,
                ),
                SizedBox(width: 6),
                Text(
                  missingHint,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.opsWarning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: canSubmit
                ? Material(
                    borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: submitting
                            ? null
                            : LinearGradient(
                                colors: [
                                  context.opsAccent,
                                  context.opsAccent.withBlue(220),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                        color: submitting
                            ? context.opsAccent.withOpacity(0.6)
                            : null,
                        borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                        boxShadow: submitting
                            ? null
                            : [
                                BoxShadow(
                                  color: context.opsAccent.withOpacity(0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: InkWell(
                        onTap: submitting ? null : onSubmit,
                        borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                        child: Center(
                          child: submitting
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: context.opsTextOnDark,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_circle_outline,
                                      size: 18,
                                      color: context.opsTextOnDark,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Захиалга үүсгэх',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: context.opsTextOnDark,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: context.opsDivider,
                      borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                    ),
                    child: Center(
                      child: Text(
                        'Захиалга үүсгэх',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.opsTextHint,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
