import 'package:carcare_service/app/shell/shell_chrome.dart';

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
  const CreateOrderScreen({
    super.key,
    required this.repository,
    this.appointmentId,
    this.initialVehicle,
    this.initialCustomer,
  });

  final OrdersRepository repository;

  /// When set (e.g. opened from the Today board's appointments timeline
  /// after the customer has arrived), the created order is linked to this
  /// appointment via `OrdersRepository.createOrder`'s `appointmentId`.
  /// [initialVehicle] / [initialCustomer] should also be supplied so the
  /// customer and vehicle steps start pre-filled with the appointment's car and
  /// owner — the user can still clear and pick a different one.
  final String? appointmentId;
  final VehicleSummary? initialVehicle;
  final CustomerSummary? initialCustomer;

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  // 1. Харилцагч — вэбтэй адил эхлээд харилцагч, дараа нь түүний машин.
  final _customerCtrl = TextEditingController();
  List<CustomerSummary> _customerResults = [];
  bool _searchingCustomer = false;
  CustomerSummary? _customer;
  Timer? _customerTimer;

  // 2. Машин — сонгосон харилцагчийн машинууд
  List<VehicleSummary> _customerVehicles = [];
  bool _loadingVehicles = false;
  VehicleSummary? _vehicle;
  int _vehiclesSeq = 0;

  // Branch + schedule + notes
  List<BranchSummary> _branches = [];
  BranchSummary? _branch;
  DateTime? _scheduledAt;
  int? _estimatedDurationMinutes;
  final _notesCtrl = TextEditingController();
  bool _submitting = false;

  // Хариуцах мастер — вэбийн order-form-той адил заавал биш, сонгосон
  // салбараар шүүгдэнэ. Зөвхөн `orders.assign` эрхтэй хэрэглэгчид харагдана
  // (сервер ч мөн адил шаарддаг).
  List<AssignableUser> _assignees = [];
  bool _loadingAssignees = false;
  String? _assigneeError;
  AssignableUser? _assignee;
  int _assigneesSeq = 0;

  final _dateFmt = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _customer = widget.initialCustomer ?? widget.initialVehicle?.customer;
    _vehicle = widget.initialVehicle;
    if (_vehicle != null) _customerVehicles = [_vehicle!];
    if (_customer != null) _loadCustomerVehicles(_customer!.id);
    _loadBranches();
    _notesCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _customerTimer?.cancel();
    _customerCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    final branches = await DiagnosticService.getBranches();
    if (!mounted) return;
    final branchId = Authenticator.user?.branchId;
    final before = _branch;
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
    if (_branch != before) _loadAssignees();
  }

  bool get _canAssign {
    final user = Authenticator.user;
    return user?.isOwner == true ||
        user?.role?.permissions.contains('orders.assign') == true;
  }

  void _selectBranch(BranchSummary b) {
    if (b.id == _branch?.id) return;
    setState(() => _branch = b);
    _loadAssignees();
  }

  Future<void> _loadAssignees() async {
    final branch = _branch;
    if (!_canAssign || branch == null) return;
    final seq = ++_assigneesSeq;
    setState(() {
      _loadingAssignees = true;
      _assigneeError = null;
    });
    final result = await widget.repository.getAssignableUsers(
      branchId: branch.id,
    );
    if (!mounted || seq != _assigneesSeq) return;
    setState(() {
      _loadingAssignees = false;
      switch (result) {
        case Ok(:final value):
          _assignees = value;
          // Салбар солиход тэр салбарт хамаарахгүй мастерыг цэвэрлэнэ.
          final keep = _assignee;
          if (keep != null && !value.any((u) => u.id == keep.id)) {
            _assignee = null;
          }
        case Err(:final error):
          _assignees = [];
          _assignee = null;
          _assigneeError = error.display;
      }
    });
  }

  void _searchCustomer(String q) {
    _customerTimer?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _customerResults = []);
      return;
    }
    _customerTimer = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _searchingCustomer = true);
      final results = await DiagnosticService.searchCustomers(q.trim());
      if (!mounted) return;
      setState(() {
        _customerResults = results;
        _searchingCustomer = false;
      });
    });
  }

  void _selectCustomer(CustomerSummary c) {
    setState(() {
      _customer = c;
      _vehicle = null;
      _customerResults = [];
      _customerCtrl.clear();
    });
    _loadCustomerVehicles(c.id);
  }

  void _clearCustomer() => setState(() {
    _customer = null;
    _vehicle = null;
    _customerVehicles = [];
    _loadingVehicles = false;
    _vehiclesSeq++;
  });

  Future<void> _loadCustomerVehicles(String customerId) async {
    final seq = ++_vehiclesSeq;
    setState(() => _loadingVehicles = true);
    final list = await DiagnosticService.vehiclesForCustomer(customerId);
    if (!mounted || seq != _vehiclesSeq) return;
    setState(() {
      // Урьдчилан сонгосон машин (цаг захиалгаас) жагсаалтад заавал харагдана.
      final keep = _vehicle;
      _customerVehicles = keep == null || list.any((v) => v.id == keep.id)
          ? list
          : [keep, ...list];
      _loadingVehicles = false;
      // Ганц машинтай бол шууд сонгоно.
      if (_vehicle == null && list.length == 1) _vehicle = list.first;
    });
  }

  Future<void> _openNewCustomer() async {
    final result = await showNewCustomerSheet(context);
    if (result != null && mounted) _selectCustomer(result);
  }

  Future<void> _openNewVehicle() async {
    final result = await Navigator.push<NewVehicleResult>(
      context,
      MaterialPageRoute(
        builder: (_) => NewVehicleScreen(initialCustomer: _customer),
      ),
    );
    if (result == null || !mounted) return;
    final owner = result.customer ?? result.vehicle.customer;
    if (owner != null && owner.id != _customer?.id) {
      // Бүртгэх үед өөр эзэмшигч сонгосон бол тэр харилцагч руу шилжинэ.
      setState(() {
        _customer = owner;
        _vehicle = result.vehicle;
      });
      _loadCustomerVehicles(owner.id);
      return;
    }
    setState(() {
      _vehicle = result.vehicle;
      if (!_customerVehicles.any((v) => v.id == result.vehicle.id)) {
        _customerVehicles = [..._customerVehicles, result.vehicle];
      }
    });
  }

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

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    final result = await widget.repository.createOrder(
      branchId: _branch!.id,
      customerId: _customer!.id,
      vehicleId: _vehicle!.id,
      assignedToId: _canAssign ? _assignee?.id : null,
      scheduledAt: _scheduledAt,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      estimatedDurationMinutes: _estimatedDurationMinutes,
      appointmentId: widget.appointmentId,
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
      _customer != null && _vehicle != null && _branch != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.opsBackground,
      appBar: AppBar(
        title: Text('Захиалга үүсгэх'),
        actions: const [ShellNotificationBell()],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 1. Харилцагч ───────────────────────────────────────
                  _SectionLabel(
                    number: '1',
                    title: 'Харилцагч сонгох',
                    done: _customer != null,
                  ),
                  const SizedBox(height: 10),
                  _CustomerSection(
                    ctrl: _customerCtrl,
                    searching: _searchingCustomer,
                    results: _customerResults,
                    selected: _customer,
                    onSearch: _searchCustomer,
                    onSelect: _selectCustomer,
                    onClear: _clearCustomer,
                    onNewCustomer: _openNewCustomer,
                  ),
                  const SizedBox(height: 24),

                  // ── 2. Машин ───────────────────────────────────────────
                  _SectionLabel(
                    number: '2',
                    title: 'Машин сонгох',
                    done: _vehicle != null,
                  ),
                  const SizedBox(height: 10),
                  _CustomerVehiclesSection(
                    customer: _customer,
                    loading: _loadingVehicles,
                    vehicles: _customerVehicles,
                    selected: _vehicle,
                    onSelect: (v) => setState(() => _vehicle = v),
                    onNewVehicle: _openNewVehicle,
                  ),
                  const SizedBox(height: 24),

                  // ── 3. Салбар ──────────────────────────────────────────
                  _SectionLabel(
                    number: '3',
                    title: 'Салбар',
                    done: _branch != null,
                  ),
                  const SizedBox(height: 10),
                  _BranchSection(
                    branches: _branches,
                    selected: _branch,
                    onSelect: _selectBranch,
                  ),
                  const SizedBox(height: 24),

                  // ── 4. Хариуцах мастер ─────────────────────────────────
                  if (_canAssign) ...[
                    _SectionLabel(
                      number: '4',
                      title: 'Хариуцах мастер',
                      done: _assignee != null,
                      optional: true,
                    ),
                    const SizedBox(height: 10),
                    _AssigneeSection(
                      users: _assignees,
                      selected: _assignee,
                      loading: _loadingAssignees,
                      error: _assigneeError,
                      onChanged: (u) => setState(() => _assignee = u),
                      onRetry: _loadAssignees,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── 5. Нэмэлт ──────────────────────────────────────────
                  _SectionLabel(
                    number: _canAssign ? '5' : '4',
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
            customer: _customer,
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

// ─── Customer section ──────────────────────────────────────────────────────────

BoxDecoration _cardDecoration(BuildContext context, {Color? border}) =>
    BoxDecoration(
      color: context.opsSurface,
      borderRadius: BorderRadius.circular(AppDimens.radiusMD),
      border: Border.all(color: border ?? context.opsDivider),
      boxShadow: [
        BoxShadow(
          color: context.opsTextPrimary.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );

class _CustomerSection extends StatelessWidget {
  final TextEditingController ctrl;
  final bool searching;
  final List<CustomerSummary> results;
  final CustomerSummary? selected;
  final ValueChanged<String> onSearch;
  final ValueChanged<CustomerSummary> onSelect;
  final VoidCallback onClear;
  final VoidCallback onNewCustomer;

  const _CustomerSection({
    required this.ctrl,
    required this.searching,
    required this.results,
    required this.selected,
    required this.onSearch,
    required this.onSelect,
    required this.onClear,
    required this.onNewCustomer,
  });

  @override
  Widget build(BuildContext context) {
    if (selected != null) {
      return Container(
        key: const ValueKey('create_order_selected_customer'),
        decoration: _cardDecoration(
          context,
          border: context.opsAccent.withOpacity(0.35),
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
                Icons.person_rounded,
                color: context.opsAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selected!.displayName,
                    style: context.textStyles.h3.copyWith(
                      color: context.opsAccent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(selected!.phone, style: context.textStyles.caption),
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

    return Column(
      children: [
        Container(
          decoration: _cardDecoration(context),
          child: TextField(
            key: const ValueKey('create_order_customer_search'),
            controller: ctrl,
            onChanged: onSearch,
            style: context.textStyles.body,
            decoration: InputDecoration(
              hintText: 'Нэр эсвэл утасны дугаараар хайх...',
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
        if (results.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: _cardDecoration(context),
            child: Column(
              children: [
                for (final (i, c) in results.take(6).indexed)
                  _PickRow(
                    icon: Icons.person_outline,
                    title: c.displayName,
                    subtitle: c.phone,
                    divider: i < results.take(6).length - 1,
                    onTap: () => onSelect(c),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        _AddButton(label: 'Шинэ харилцагч бүртгэх', onTap: onNewCustomer),
      ],
    );
  }
}

// ─── Customer's vehicles ───────────────────────────────────────────────────────

class _CustomerVehiclesSection extends StatelessWidget {
  final CustomerSummary? customer;
  final bool loading;
  final List<VehicleSummary> vehicles;
  final VehicleSummary? selected;
  final ValueChanged<VehicleSummary> onSelect;
  final VoidCallback onNewVehicle;

  const _CustomerVehiclesSection({
    required this.customer,
    required this.loading,
    required this.vehicles,
    required this.selected,
    required this.onSelect,
    required this.onNewVehicle,
  });

  @override
  Widget build(BuildContext context) {
    if (customer == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(context),
        child: Text(
          'Эхлээд харилцагч сонгоно уу.',
          style: context.textStyles.caption,
        ),
      );
    }
    if (loading && vehicles.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(context),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              'Машинуудыг ачааллаж байна...',
              style: context.textStyles.caption,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (vehicles.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: _cardDecoration(context),
            child: Text(
              'Энэ харилцагчид бүртгэлтэй машин алга.',
              style: context.textStyles.caption,
            ),
          )
        else
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: _cardDecoration(context),
            child: Column(
              children: [
                for (final (i, v) in vehicles.indexed)
                  _PickRow(
                    key: ValueKey('create_order_vehicle_${v.id}'),
                    icon: Icons.directions_car_outlined,
                    title: v.plate,
                    subtitle: v.displayName,
                    selected: v.id == selected?.id,
                    divider: i < vehicles.length - 1,
                    onTap: () => onSelect(v),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        _AddButton(label: 'Шинэ машин бүртгэх', onTap: onNewVehicle),
      ],
    );
  }
}

class _PickRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool divider;
  final VoidCallback onTap;

  const _PickRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.divider,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? context.opsAccent.withOpacity(0.06) : null,
          border: divider
              ? Border(bottom: BorderSide(color: context.opsDivider))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.opsAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppDimens.radiusSM),
              ),
              child: Icon(icon, color: context.opsAccent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.textStyles.bodyMedium.copyWith(
                      color: selected ? context.opsAccent : null,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, style: context.textStyles.caption),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.chevron_right,
              size: 18,
              color: selected ? context.opsAccent : context.opsTextHint,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AddButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: context.opsSurface,
          borderRadius: BorderRadius.circular(AppDimens.radiusMD),
          border: Border.all(color: context.opsAccent.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.add_circle_outline, size: 18, color: context.opsAccent),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.opsAccent,
              ),
            ),
          ],
        ),
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

// ─── Assignee ──────────────────────────────────────────────────────────────────

class _AssigneeSection extends StatelessWidget {
  final List<AssignableUser> users;
  final AssignableUser? selected;
  final bool loading;
  final String? error;
  final ValueChanged<AssignableUser?> onChanged;
  final VoidCallback onRetry;
  const _AssigneeSection({
    required this.users,
    required this.selected,
    required this.loading,
    required this.error,
    required this.onChanged,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (loading && users.isEmpty) {
      child = Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            'Мастеруудыг ачааллаж байна...',
            style: context.textStyles.caption,
          ),
        ],
      );
    } else if (error != null) {
      child = Row(
        children: [
          Expanded(
            child: Text(
              error!,
              style: context.textStyles.caption.copyWith(
                color: context.opsTextSecondary,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Дахин')),
        ],
      );
    } else {
      child = DropdownButtonFormField<String?>(
        // Keyed by selection so a branch change that clears it rebuilds.
        key: ValueKey('create_order_assignee_${selected?.id}'),
        initialValue: selected?.id,
        isExpanded: true,
        decoration: const InputDecoration(
          hintText: 'Сонгоогүй',
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
        ),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Сонгоогүй'),
          ),
          for (final u in users)
            DropdownMenuItem<String?>(
              value: u.id,
              child: Text(
                u.fullName.isEmpty ? '—' : u.fullName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (id) =>
            onChanged(id == null ? null : users.firstWhere((u) => u.id == id)),
      );
    }
    return Container(
      key: const ValueKey('create_order_assignee'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.opsSurface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMD),
        border: Border.all(color: context.opsDivider),
      ),
      child: child,
    );
  }
}

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
  final CustomerSummary? customer;
  final VehicleSummary? vehicle;
  final BranchSummary? branch;
  final DateTime? scheduledAt;
  final DateFormat dateFmt;
  final bool canSubmit;
  final bool submitting;
  final VoidCallback onSubmit;

  const _BottomBar({
    required this.customer,
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
    final String? missingHint = customer == null
        ? 'Харилцагч сонгоогүй байна'
        : vehicle == null
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
