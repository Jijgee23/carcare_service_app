import 'package:carcare_service/core/theme/app_theme.dart';
import 'package:carcare_service/core/utils/validators.dart';
import 'package:carcare_service/features/models/service_catalog.dart';
import 'package:carcare_service/features/presentation/controllers/controllers.dart';
import 'package:carcare_service/shared/widgets/picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class CreateServiceScreen extends StatelessWidget {
  final ServiceKind initialType;
  const CreateServiceScreen({super.key, this.initialType = ServiceKind.LABOR});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CreateServiceController(initialType: initialType)..init(),
      child: const _CreateServiceBody(),
    );
  }
}

class _CreateServiceBody extends StatefulWidget {
  const _CreateServiceBody();

  @override
  State<_CreateServiceBody> createState() => _CreateServiceBodyState();
}

class _CreateServiceBodyState extends State<_CreateServiceBody> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _costPriceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _priceCtrl.dispose();
    _costPriceCtrl.dispose();
    _stockCtrl.dispose();
    _durationCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool _canSubmit(CreateServiceController ctrl) =>
      !ctrl.submitting &&
      !ctrl.loadingLookups &&
      _nameCtrl.text.trim().isNotEmpty &&
      _priceCtrl.text.trim().isNotEmpty;

  Future<void> _submit(CreateServiceController ctrl) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final service = await ctrl.submit(
      name: _nameCtrl.text.trim(),
      code: _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim(),
      price: double.tryParse(_priceCtrl.text.trim()) ?? 0,
      costPrice: _costPriceCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_costPriceCtrl.text.trim()),
      stock: _stockCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_stockCtrl.text.trim()),
      durationValue: _durationCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_durationCtrl.text.trim()),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
    );

    if (service != null && mounted) Navigator.pop(context, service);
  }

  Future<void> _pickUnit(CreateServiceController ctrl) async {
    if (ctrl.units.isEmpty) return;
    final picked = await PickerScreen.push<ServiceUnit>(
      context,
      title: 'Хэмжих нэгж',
      items: ctrl.units,
      selected: ctrl.selectedUnit,
      label: (u) => u.name,
      subtitle: (u) => u.code,
    );
    if (picked != null) ctrl.setUnit(picked);
  }

  Future<void> _pickCategory(CreateServiceController ctrl) async {
    if (ctrl.categories.isEmpty) return;
    final picked = await PickerScreen.push<LaborCategory>(
      context,
      title: 'Ажлын ангилал',
      items: ctrl.categories,
      selected: ctrl.selectedCategory,
      label: (c) => c.name,
    );
    if (picked != null) ctrl.setCategory(picked);
  }

  Future<void> _pickDurationUnit(CreateServiceController ctrl) async {
    if (ctrl.units.isEmpty) return;
    final picked = await PickerScreen.push<ServiceUnit>(
      context,
      title: 'Хугацааны нэгж',
      items: ctrl.units,
      selected: ctrl.selectedDurationUnit,
      label: (u) => u.name,
      subtitle: (u) => u.code,
    );
    if (picked != null) ctrl.setDurationUnit(picked);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<CreateServiceController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Үйлчилгээ бүртгэх')),
      body: ctrl.loadingLookups
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Төрөл ──────────────────────────────────────────
                    _Section(
                      title: 'Төрөл',
                      child: Row(
                        children: ServiceKind.values.map((k) {
                          final active = ctrl.type == k;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                  right: k != ServiceKind.DIAGNOSTIC ? 8 : 0),
                              child: GestureDetector(
                                onTap: () => ctrl.setType(k),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? k.color.withOpacity(0.12)
                                        : AppColors.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: active
                                          ? k.color
                                          : AppColors.divider,
                                      width: active ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(k.icon,
                                          size: 20,
                                          color: active
                                              ? k.color
                                              : AppColors.textSecondary),
                                      const SizedBox(height: 4),
                                      Text(
                                        k.label,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: active
                                              ? FontWeight.w700
                                              : FontWeight.w400,
                                          color: active
                                              ? k.color
                                              : AppColors.textSecondary,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ─── Ажлын ангилал (LABOR only) ─────────────────────
                    if (ctrl.showCategory) ...[
                      _Section(
                        title: 'Ажлын ангилал',
                        child: _PickerTile(
                          label: 'Ангилал сонгох',
                          value: ctrl.selectedCategory?.name,
                          onTap: () => _pickCategory(ctrl),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ─── Үндсэн мэдээлэл ────────────────────────────────
                    _Section(
                      title: 'Үндсэн мэдээлэл',
                      child: Column(
                        children: [
                          _Field(
                            controller: _nameCtrl,
                            label: 'Нэр',
                            hint: 'Тос солих, Тоормосны шингэн...',
                            required: true,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          _Field(
                            controller: _codeCtrl,
                            label: 'Код / SKU',
                            hint: 'SVC-001 (заавал биш)',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ─── Хэмжих нэгж (LABOR + GOODS) ───────────────────
                    if (ctrl.showUnit) ...[
                      _Section(
                        title: 'Хэмжих нэгж',
                        child: _PickerTile(
                          label: 'Нэгж сонгох',
                          value: ctrl.selectedUnit?.name,
                          valueSubtitle: ctrl.selectedUnit?.code,
                          onTap: () => _pickUnit(ctrl),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ─── Үнэ ────────────────────────────────────────────
                    _Section(
                      title: 'Үнэ',
                      child: Column(
                        children: [
                          _Field(
                            controller: _priceCtrl,
                            label: 'Зарах үнэ ₮',
                            hint: '0',
                            required: true,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*'))
                            ],
                            onChanged: (_) => setState(() {}),
                          ),
                          if (ctrl.showCostAndStock) ...[
                            const SizedBox(height: 12),
                            _Field(
                              controller: _costPriceCtrl,
                              label: 'Өртөг ₮',
                              hint: '0 (заавал биш)',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d*'))
                              ],
                            ),
                            const SizedBox(height: 12),
                            _Field(
                              controller: _stockCtrl,
                              label: 'Нөөц тоо ширхэг',
                              hint: '0',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d*'))
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ─── Үргэлжлэх хугацаа (LABOR + DIAGNOSTIC) ────────
                    if (ctrl.showDuration) ...[
                      _Section(
                        title: 'Үргэлжлэх хугацаа',
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: _Field(
                                controller: _durationCtrl,
                                label: 'Хугацаа',
                                hint: '1.5 (заавал биш)',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*\.?\d*'))
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: _PickerTile(
                                label: 'Нэгж',
                                value: ctrl.selectedDurationUnit?.name,
                                valueSubtitle:
                                    ctrl.selectedDurationUnit?.code,
                                onTap: () => _pickDurationUnit(ctrl),
                                compact: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ─── Тайлбар ────────────────────────────────────────
                    _Section(
                      title: 'Тайлбар',
                      child: _Field(
                        controller: _descCtrl,
                        label: 'Тайлбар',
                        hint: 'Нэмэлт мэдээлэл (заавал биш)',
                        maxLines: 3,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ─── Тохиргоо ───────────────────────────────────────
                    _Section(
                      title: 'Тохиргоо',
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Идэвхтэй',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary)),
                              Text('Захиалгад харагдана',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                          Switch(
                            value: ctrl.isActive,
                            onChanged: ctrl.setIsActive,
                            activeColor: AppColors.accent,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ─── Submit ─────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed:
                            _canSubmit(ctrl) ? () => _submit(ctrl) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          disabledBackgroundColor:
                              AppColors.accent.withOpacity(0.4),
                        ),
                        child: ctrl.submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : const Text('Бүртгэх',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }
}

// ─── Picker tile ──────────────────────────────────────────────────────────────

class _PickerTile extends StatelessWidget {
  final String label;
  final String? value;
  final String? valueSubtitle;
  final VoidCallback onTap;
  final bool compact;

  const _PickerTile({
    required this.label,
    required this.onTap,
    this.value,
    this.valueSubtitle,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: 14, vertical: compact ? 11 : 14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!hasValue)
                    Text(label,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textHint))
                  else ...[
                    Text(value!,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary)),
                    if (valueSubtitle != null &&
                        valueSubtitle!.isNotEmpty)
                      Text(valueSubtitle!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

// ─── Section card ─────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textHint,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ─── Field ────────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final void Function(String)? onChanged;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      validator: required ? (v) => AppValidators.required(v, label) : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle:
            const TextStyle(color: AppColors.textHint, fontSize: 13),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
