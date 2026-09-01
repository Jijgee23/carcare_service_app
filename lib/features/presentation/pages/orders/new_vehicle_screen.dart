import 'dart:async';

import 'package:carcare_service/core/theme/app_theme.dart';
import 'package:carcare_service/core/utils/validators.dart';
import 'package:carcare_service/features/models/diagnostic.dart';
import 'package:carcare_service/features/presentation/pages/orders/new_customer_sheet.dart';
import 'package:carcare_service/core/services/diagnostic_service.dart';
import 'package:flutter/material.dart';
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
  const NewVehicleScreen({super.key, this.initialPlate});

  @override
  State<NewVehicleScreen> createState() => _NewVehicleScreenState();
}

class _NewVehicleScreenState extends State<NewVehicleScreen> with ValidatorMixin {
  final _formKey = GlobalKey<FormState>();
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

  @override
  void initState() {
    super.initState();
    if (widget.initialPlate != null) {
      _plateCtrl.text = widget.initialPlate!;
    }
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
      final results = await DiagnosticService.searchCustomers(q.trim());
      if (!mounted) return;
      setState(() {
        _custResults = results;
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
    setState(() => _saving = true);

    final vehicle = await DiagnosticService.createVehicle(
      plate: _plateCtrl.text.trim().toUpperCase(),
      make: _makeCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      year: int.tryParse(_yearCtrl.text.trim()),
      vin: _vinCtrl.text.trim().isEmpty ? null : _vinCtrl.text.trim(),
      mileage: int.tryParse(_mileCtrl.text.trim()),
      customerId: _customer?.id,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (vehicle == null) return;

    // Embed customer into vehicle object manually (API doesn't return it)
    final withCustomer = VehicleSummary(
      id: vehicle.id,
      plate: vehicle.plate,
      make: vehicle.make,
      model: vehicle.model,
      year: vehicle.year,
      vin: vehicle.vin,
      mileage: vehicle.mileage,
      customerId: vehicle.customerId ?? _customer?.id,
      customer: _customer,
    );

    Navigator.pop(context, NewVehicleResult(vehicle: withCustomer, customer: _customer));
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Шинэ машин бүртгэх')),
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
                    // ── Машины мэдээлэл ──────────────────────────────────
                    _SectionHeader(icon: Icons.directions_car_outlined, title: 'Машины мэдээлэл'),
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
                                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9А-Яа-яЁё]')),
                                _UpperCaseFormatter(),
                              ],
                              validator: plateValidator,
                              style: AppTextStyles.body,
                              decoration: InputDecoration(
                                hintText: '1234ҮНА',
                                suffixIcon: _hurLoading
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      )
                                    : IconButton(
                                        icon: Icon(
                                          Icons.search,
                                          color: _hurFound ? AppColors.good : AppColors.accent,
                                          size: 20,
                                        ),
                                        tooltip: 'ХУР-аас хайх',
                                        onPressed: _lookupHur,
                                      ),
                              ),
                            ),
                          ),

                          if (_hurFound) ...[
                            const SizedBox(height: 8),
                            _InfoBanner(
                              icon: Icons.check_circle_outline,
                              color: AppColors.good,
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
                                    textCapitalization: TextCapitalization.words,
                                    validator: requiredField('Марк'),
                                    style: AppTextStyles.body,
                                    decoration: const InputDecoration(hintText: 'Toyota'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _LabelField(
                                  label: 'Загвар *',
                                  child: TextFormField(
                                    controller: _modelCtrl,
                                    textCapitalization: TextCapitalization.words,
                                    validator: requiredField('Загвар'),
                                    style: AppTextStyles.body,
                                    decoration: const InputDecoration(hintText: 'Prius'),
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
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    style: AppTextStyles.body,
                                    decoration: const InputDecoration(hintText: '2020'),
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
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    style: AppTextStyles.body,
                                    decoration: const InputDecoration(hintText: '85000'),
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
                              style: AppTextStyles.body,
                              decoration: const InputDecoration(hintText: 'JTDKN3DU...'),
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
                              label: const Text('Шинэ'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.accent,
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            )
                          : null,
                    ),
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
                              style: AppTextStyles.body,
                              decoration: InputDecoration(
                                hintText: 'Нэр, утсаар хайх...',
                                prefixIcon: const Icon(
                                  Icons.search,
                                  size: 18,
                                  color: AppColors.textHint,
                                ),
                                suffixIcon: _searchingCust
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
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
                                            const Icon(
                                              Icons.person_outline,
                                              size: 16,
                                              color: AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    c.displayName,
                                                    style: AppTextStyles.bodyMedium,
                                                  ),
                                                  Text(c.phone, style: AppTextStyles.caption),
                                                ],
                                              ),
                                            ),
                                            const Icon(
                                              Icons.add,
                                              size: 16,
                                              color: AppColors.accent,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                            ],
                            if (_custResults.isEmpty && _custCtrl.text.isEmpty) ...[
                              const Divider(height: 1),
                              InkWell(
                                onTap: _openNewCustomer,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.person_add_outlined,
                                        size: 16,
                                        color: AppColors.accent,
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'Шинэ үйлчлүүлэгч бүртгэх',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.accent,
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
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Машин бүртгэх',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
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
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue value) =>
      value.copyWith(text: value.text.toUpperCase());
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  const _SectionHeader({required this.icon, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppDimens.radiusSM),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: AppTextStyles.h3)),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMD),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
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
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1));
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _InfoBanner({required this.icon, required this.color, required this.text});

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
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMD),
        border: Border.all(color: AppColors.good.withOpacity(0.4), width: 1.5),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.good.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                customer.displayName.isNotEmpty ? customer.displayName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.good,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.displayName, style: AppTextStyles.bodyMedium),
                Text(customer.phone, style: AppTextStyles.caption),
                if (customer.email != null && customer.email!.isNotEmpty)
                  Text(
                    customer.email!,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onClear,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 14, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
