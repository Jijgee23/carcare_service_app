import 'package:carcare_service/app/shell/shell_chrome.dart';
import 'dart:async';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/utils/validators.dart';
import 'package:carcare_service/core/domain/diagnostic.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/customers/data/customer_repository.dart';
import 'package:carcare_service/features/customers/domain/customers_repository.dart';
import 'package:carcare_service/features/orders/presentation/screens/new_customer_sheet.dart';
import 'package:carcare_service/core/services/diagnostic_service.dart';
import 'package:carcare_service/features/vehicles/data/vehicle_repository.dart';
import 'package:carcare_service/features/vehicles/domain/vehicles_repository.dart';
import 'package:flutter/material.dart';
import 'package:carcare_service/features/orders/presentation/feature_theme.dart';
import 'package:flutter/services.dart';

// Return type — vehicle + resolved customer
class NewVehicleResult {
  final VehicleSummary vehicle;
  final CustomerSummary? customer;
  const NewVehicleResult({required this.vehicle, required this.customer});
}

class NewVehicleScreen extends StatefulWidget {
  /// Pre-fill plate if triggered from a search with no result
  final String? initialPlate;

  /// Pre-select the owner (order creation picks the customer first).
  final CustomerSummary? initialCustomer;

  /// Injectable for tests; defaults to the real remote adapters in
  /// production, matching every other screen promoted onto the `P3-F1`
  /// repositories.
  final VehiclesRepository? vehiclesRepository;
  final CustomersRepository? customersRepository;

  const NewVehicleScreen({
    super.key,
    this.initialPlate,
    this.initialCustomer,
    this.vehiclesRepository,
    this.customersRepository,
  });

  @override
  State<NewVehicleScreen> createState() => _NewVehicleScreenState();
}

class _NewVehicleScreenState extends State<NewVehicleScreen>
    with ValidatorMixin {
  final _formKey = GlobalKey<FormState>();
  late final VehiclesRepository _vehiclesRepo =
      widget.vehiclesRepository ?? RemoteVehiclesRepository();
  late final CustomersRepository _customersRepo =
      widget.customersRepository ?? RemoteCustomersRepository();
  final _plateCtrl = TextEditingController();
  final _makeCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _vinCtrl = TextEditingController();
  final _mileCtrl = TextEditingController();

  // Customer
  final _custCtrl = TextEditingController();
  List<CustomerSummary> _custResults = [];
  bool _searchingCust = false;
  CustomerSummary? _customer;
  Timer? _custTimer;

  // HUR lookup
  bool _hurLoading = false;
  bool _hurFound = false;

  bool _saving = false;
  String? _generalError;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    if (widget.initialPlate != null) {
      _plateCtrl.text = widget.initialPlate!;
    }
    _customer = widget.initialCustomer;
  }

  @override
  void dispose() {
    _plateCtrl.dispose();
    _makeCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _vinCtrl.dispose();
    _mileCtrl.dispose();
    _custCtrl.dispose();
    _custTimer?.cancel();
    super.dispose();
  }

  // ─── HUR lookup ────────────────────────────────────────────────────────────

  Future<void> _lookupHur() async {
    final plate = _plateCtrl.text.trim();
    if (plate.isEmpty) return;
    setState(() {
      _hurLoading = true;
      _hurFound = false;
    });
    final info = await DiagnosticService.lookupHurVehicle(plate);
    if (!mounted) return;
    if (info != null) {
      _makeCtrl.text = (info['mark'] ?? info['make'] ?? '').toString();
      _modelCtrl.text = (info['model'] ?? '').toString();
      final y = info['year'] ?? info['releaseYear'];
      if (y != null) _yearCtrl.text = y.toString();
      setState(() {
        _hurFound = true;
      });
    }
    setState(() => _hurLoading = false);
  }

  // ─── Customer search ────────────────────────────────────────────────────────

  void _searchCustomer(String q) {
    _custTimer?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _custResults = [];
      });
      return;
    }
    _custTimer = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _searchingCust = true);
      final result = await _customersRepo.getCustomers(
        query: CustomerListQuery(q: q.trim()),
      );
      if (!mounted) return;
      setState(() {
        _custResults = switch (result) {
          Ok(:final value) =>
            value.items
                .map(
                  (c) => CustomerSummary(
                    id: c.id,
                    fullName: c.fullName,
                    phone: c.phone ?? '',
                    email: c.email,
                  ),
                )
                .toList(growable: false),
          Err() => const <CustomerSummary>[],
        };
        _searchingCust = false;
      });
    });
  }

  void _selectCustomer(CustomerSummary c) => setState(() {
    _customer = c;
    _custResults = [];
    _custCtrl.clear();
  });

  Future<void> _openNewCustomer() async {
    final result = await showNewCustomerSheet(context);
    if (result != null && mounted) _selectCustomer(result);
  }

  // ─── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _generalError = null;
      _fieldErrors = const {};
    });

    final plate = _plateCtrl.text.trim().toUpperCase();
    final make = _makeCtrl.text.trim();
    final model = _modelCtrl.text.trim();

    final result = await _vehiclesRepo.createVehicle(
      plate: plate,
      make: make,
      model: model,
      year: int.tryParse(_yearCtrl.text.trim()),
      vin: _vinCtrl.text.trim().isEmpty ? null : _vinCtrl.text.trim(),
      mileage: int.tryParse(_mileCtrl.text.trim()),
      customerId: _customer?.id,
    );

    if (!mounted) return;

    switch (result) {
      case Ok(:final value):
        setState(() => _saving = false);
        // `POST /vehicles` returns the link's REAL owner, which may differ
        // from the requested `customerId` (`ensureTenantVehicle` never
        // overwrites an existing owner) — render what came back, never echo
        // the request. The response omits the nested `customer` block, so
        // the locally-known [_customer] is carried over only when the
        // returned id still matches what was sent.
        final withCustomer = VehicleSummary(
          id: value.id,
          plate: value.plate ?? plate,
          make: value.make ?? make,
          model: value.model ?? model,
          year: value.year,
          vin: value.vin,
          mileage: value.mileage,
          customerId: value.customerId ?? _customer?.id,
          customer:
              (value.customerId == null || value.customerId == _customer?.id)
              ? _customer
              : null,
        );

        Navigator.pop(
          context,
          NewVehicleResult(vehicle: withCustomer, customer: _customer),
        );
      case Err(:final error):
        setState(() {
          _saving = false;
          _fieldErrors = error.fieldErrors ?? const {};
          _generalError =
              (error.fieldErrors == null || error.fieldErrors!.isEmpty)
              ? error.display
              : null;
        });
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.opsBackground,
      appBar: AppBar(
        title: Text('Шинэ машин бүртгэх'),
        actions: const [ShellNotificationBell()],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_generalError != null) ...[
                      _InfoBanner(
                        icon: Icons.error_outline,
                        color: context.opsDanger,
                        text: _generalError!,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Машины мэдээлэл ──────────────────────────────────
                    _SectionHeader(
                      icon: Icons.directions_car_outlined,
                      title: 'Машины мэдээлэл',
                    ),
                    const SizedBox(height: 12),
                    _Card(
                      child: Column(
                        children: [
                          // Plate + HUR button
                          _LabelField(
                            label: 'Улсын дугаар *',
                            child: TextFormField(
                              controller: _plateCtrl,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[A-Za-z0-9А-Яа-яЁё]'),
                                ),
                                _UpperCaseFormatter(),
                              ],
                              validator: plateValidator,
                              style: context.textStyles.body,
                              decoration: InputDecoration(
                                hintText: '1234ҮНА',
                                errorText: _fieldErrors['plate'],
                                suffixIcon: _hurLoading
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    : IconButton(
                                        icon: Icon(
                                          Icons.search,
                                          color: _hurFound
                                              ? context.opsGood
                                              : context.opsAccent,
                                          size: 20,
                                        ),
                                        tooltip: 'ХУР-аас хайх',
                                        onPressed: _lookupHur,
                                      ),
                              ),
                            ),
                          ),

                          if (_hurFound) ...[
                            SizedBox(height: 8),
                            _InfoBanner(
                              icon: Icons.check_circle_outline,
                              color: context.opsGood,
                              text: 'ХУР-аас мэдээлэл олдлоо — талбарууд автоматаар бөглөгдлөө',
                            ),
                          ],

                          const _Divider(),

                          // Make + Model
                          Row(
                            children: [
                              Expanded(
                                child: _LabelField(
                                  label: 'Марк *',
                                  child: TextFormField(
                                    controller: _makeCtrl,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    validator: requiredField('Марк'),
                                    style: context.textStyles.body,
                                    decoration: InputDecoration(
                                      hintText: 'Toyota',
                                      errorText: _fieldErrors['make'],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _LabelField(
                                  label: 'Загвар *',
                                  child: TextFormField(
                                    controller: _modelCtrl,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    validator: requiredField('Загвар'),
                                    style: context.textStyles.body,
                                    decoration: InputDecoration(
                                      hintText: 'Prius',
                                      errorText: _fieldErrors['model'],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const _Divider(),

                          // Year + Mileage
                          Row(
                            children: [
                              Expanded(
                                child: _LabelField(
                                  label: 'Он',
                                  child: TextFormField(
                                    controller: _yearCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    style: context.textStyles.body,
                                    decoration: InputDecoration(
                                      hintText: '2020',
                                      errorText: _fieldErrors['year'],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _LabelField(
                                  label: 'Гүйлт (км)',
                                  child: TextFormField(
                                    controller: _mileCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    style: context.textStyles.body,
                                    decoration: InputDecoration(
                                      hintText: '85000',
                                      errorText: _fieldErrors['mileage'],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const _Divider(),

                          // VIN
                          _LabelField(
                            label: 'VIN дугаар',
                            child: TextFormField(
                              controller: _vinCtrl,
                              textCapitalization: TextCapitalization.characters,
                              style: context.textStyles.body,
                              decoration: InputDecoration(
                                hintText: 'JTDKN3DU...',
                                errorText: _fieldErrors['vin'],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Эзэмшигч ─────────────────────────────────────────
                    _SectionHeader(
                      icon: Icons.person_outline,
                      title: 'Эзэмшигч',
                      trailing: _customer == null
                          ? TextButton.icon(
                              onPressed: _openNewCustomer,
                              icon: const Icon(Icons.add, size: 16),
                              label: Text('Шинэ'),
                              style: TextButton.styleFrom(
                                foregroundColor: context.opsAccent,
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            )
                          : null,
                    ),
                    if (_fieldErrors['customerId'] != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _fieldErrors['customerId']!,
                          style: TextStyle(
                            color: context.opsDanger,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    if (_customer != null) ...[
                      _SelectedCustomerCard(
                        customer: _customer!,
                        onClear: () => setState(() => _customer = null),
                      ),
                    ] else ...[
                      _Card(
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _custCtrl,
                              onChanged: _searchCustomer,
                              style: context.textStyles.body,
                              decoration: InputDecoration(
                                hintText: 'Нэр, утсаар хайх...',
                                prefixIcon: Icon(
                                  Icons.search,
                                  size: 18,
                                  color: context.opsTextHint,
                                ),
                                suffixIcon: _searchingCust
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    : null,
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                            ),
                            if (_custResults.isNotEmpty) ...[
                              const Divider(height: 1),
                              ..._custResults
                                  .take(4)
                                  .map(
                                    (c) => InkWell(
                                      onTap: () => _selectCustomer(c),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.person_outline,
                                              size: 16,
                                              color: context.opsTextSecondary,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    c.displayName,
                                                    style: context
                                                        .textStyles
                                                        .bodyMedium,
                                                  ),
                                                  Text(
                                                    c.phone,
                                                    style: context
                                                        .textStyles
                                                        .caption,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.add,
                                              size: 16,
                                              color: context.opsAccent,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                            ],
                            if (_custResults.isEmpty &&
                                _custCtrl.text.isEmpty) ...[
                              Divider(height: 1),
                              InkWell(
                                onTap: _openNewCustomer,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.person_add_outlined,
                                        size: 16,
                                        color: context.opsAccent,
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'Шинэ үйлчлүүлэгч бүртгэх',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: context.opsAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Sticky submit
            Container(
              decoration: BoxDecoration(
                color: context.opsSurface,
                border: Border(top: BorderSide(color: context.opsDivider)),
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                12 + MediaQuery.of(context).padding.bottom,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
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
                              Icons.check_circle_outline,
                              size: 18,
                              color: context.opsTextOnDark,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Машин бүртгэх',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: context.opsTextOnDark,
                              ),
                            ),
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
}

// ─── Local helpers ─────────────────────────────────────────────────────────────

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue old,
    TextEditingValue value,
  ) => value.copyWith(text: value.text.toUpperCase());
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: context.opsPrimary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppDimens.radiusSM),
          ),
          child: Icon(icon, size: 16, color: context.opsPrimary),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: context.textStyles.h3)),
        ?trailing,
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

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
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }
}

class _LabelField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabelField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.opsTextSecondary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 10),
    child: Divider(height: 1),
  );
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppDimens.radiusSM),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedCustomerCard extends StatelessWidget {
  final CustomerSummary customer;
  final VoidCallback onClear;
  const _SelectedCustomerCard({required this.customer, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.opsSurface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMD),
        border: Border.all(color: context.opsGood.withOpacity(0.4), width: 1.5),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.opsGood.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                customer.displayName.isNotEmpty
                    ? customer.displayName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.opsGood,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.displayName,
                  style: context.textStyles.bodyMedium,
                ),
                Text(customer.phone, style: context.textStyles.caption),
                if (customer.email != null && customer.email!.isNotEmpty)
                  Text(
                    customer.email!,
                    style: context.textStyles.caption.copyWith(
                      color: context.opsTextHint,
                    ),
                  ),
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
                size: 14,
                color: context.opsTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
