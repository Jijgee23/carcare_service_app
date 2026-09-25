import 'package:carcare_service/features/shell/presentation/controllers/working_branch_controller.dart';
import 'package:carcare_service/app/shell/shell_chrome.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/domain/diagnostic.dart';
import 'package:carcare_service/core/domain/models.dart';
import 'package:carcare_service/features/controllers.dart';
import 'package:carcare_service/core/services/diagnostic_service.dart';
import 'package:carcare_service/core/widgets/dialogs/message.dart';
import 'package:carcare_service/core/widgets/common/common_widgets.dart';
import 'package:carcare_service/core/widgets/adaptive/permission_gate.dart';
import 'package:carcare_service/features/diagnostics/presentation/screens/create_template_screen.dart';
import 'package:carcare_service/features/diagnostics/presentation/screens/report_detail_screen.dart';
import 'package:carcare_service/core/utils/upload_image.dart';

// ─── АЛХАМ 0: Template сонгох ─────────────────────────────────────────────────

// NewInspectionScreen өөрөө NewInspectionController provide хийдэг.
// Ингэснээр screen pop болоход controller автоматаар dispose хийгдэнэ.
class NewInspectionScreen extends StatelessWidget {
  const NewInspectionScreen({super.key});

  /// Called from order detail: pre-fills provider and jumps straight to checklist.
  static Future<void> pushFromOrder(
    BuildContext context, {
    required String orderId,
    required String itemId,
    required VehicleSummary vehicle,
    required CustomerSummary customer,
    required String templateId,
  }) async {
    if (!canSeeView(Authenticator.user, 'diagnostics.create')) {
      messageError('Оношилгооны тайлан үүсгэх эрх хүрэлцэхгүй байна.');
      return;
    }
    final provider = NewInspectionController();
    try {
      provider.setOrderId(orderId);
      provider.setItemId(itemId);
      provider.setVehicle(vehicle, customer: customer);
      await provider.selectTemplate(templateId);
      if (!context.mounted || provider.template == null) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: _orderFormRouteName),
          builder: (_) => ChangeNotifierProvider.value(
            value: provider,
            child: const _ChecklistStep(),
          ),
        ),
      );
    } finally {
      provider.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NewInspectionController(),
      child: const _NewInspectionBody(),
    );
  }
}

class _NewInspectionBody extends StatefulWidget {
  const _NewInspectionBody();

  @override
  State<_NewInspectionBody> createState() => _NewInspectionBodyState();
}

class _NewInspectionBodyState extends State<_NewInspectionBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NewInspectionController>().loadTemplates();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<NewInspectionController>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Оношилгооны загвар'),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        actions: const [ShellNotificationBell()],
      ),
      floatingActionButton: PermissionGate(
        permission: 'diagnostics.create',
        child: FloatingActionButton.extended(
          onPressed: () async {
            final result = await Navigator.push<dynamic>(
              context,
              MaterialPageRoute(builder: (_) => const CreateTemplateScreen()),
            );
            if (result != null && context.mounted) {
              context.read<NewInspectionController>().loadTemplates();
            }
          },
          backgroundColor: context.colors.accent,
          foregroundColor: CarCareTheme.of(context).onAccent,
          icon: const Icon(Icons.add_rounded),
          label: Text(
            'Загвар үүсгэх',
            style: context.textStyles.body.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      body: PermissionGate(
        permission: 'diagnostics.create',
        fallback: const Center(
          child: Text('Оношилгооны тайлан үүсгэх эрх хүрэлцэхгүй байна.'),
        ),
        child: prov.loadingTemplates
            ? const AppLoading()
            : prov.templates.isEmpty
            ? const EmptyState(
                message: 'Оношилгооны загвар олдсонгүй.\nВеб дашбоардаас загвар үүсгэнэ үү.',
                icon: Icons.description_outlined,
              )
            : ListView(
                padding: const EdgeInsets.all(AppDimens.paddingMD),
                children: [
                  Text('Загвар сонгоно уу', style: context.textStyles.h3),
                  const SizedBox(height: 4),
                  Text(
                    'Тайлан бөглөхийн өмнө загвараа сонгоно уу.',
                    style: context.textStyles.caption,
                  ),
                  const SizedBox(height: 16),
                  ...prov.templates.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TemplateCard(
                        template: t,
                        onTap: () => _onSelectTemplate(context, t.id),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _onSelectTemplate(BuildContext context, String id) async {
    final prov = context.read<NewInspectionController>();
    prov.reset();
    await prov.selectTemplate(id);
    if (!context.mounted) return;
    if (prov.template == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: prov,
          child: const _VehicleStep(),
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final DiagnosticTemplateSummary template;
  final VoidCallback onTap;
  const _TemplateCard({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.colors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDimens.radiusMD),
            ),
            child: Icon(
              Icons.description_outlined,
              color: context.colors.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template.name, style: context.textStyles.bodyMedium),
                const SizedBox(height: 2),
                Text(template.type.label, style: context.textStyles.caption),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.colors.textHint),
        ],
      ),
    );
  }
}

// ─── АЛХАМ 1: Машин / Үйлчлүүлэгч ───────────────────────────────────────────

class _VehicleStep extends StatefulWidget {
  const _VehicleStep();

  @override
  State<_VehicleStep> createState() => _VehicleStepState();
}

class _VehicleStepState extends State<_VehicleStep> {
  final _plateCtrl = TextEditingController();
  List<VehicleSummary> _results = [];
  bool _searching = false;
  bool _showCreateForm = false;

  // HUR lookup state
  bool _hurLoading = false;
  bool _hurFound = false;

  // Create form controllers
  final _makeCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _vinCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _mileageCtrl = TextEditingController();

  // Customer search
  final _custSearchCtrl = TextEditingController();
  List<CustomerSummary> _customerResults = [];
  bool _searchingCustomers = false;
  CustomerSummary? _selectedCustomer;
  Timer? _custSearchTimer;

  // Customer create form
  final _custNameCtrl = TextEditingController();
  final _custPhoneCtrl = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _custSearchTimer?.cancel();
    _plateCtrl.dispose();
    _makeCtrl.dispose();
    _modelCtrl.dispose();
    _vinCtrl.dispose();
    _yearCtrl.dispose();
    _mileageCtrl.dispose();
    _custSearchCtrl.dispose();
    _custNameCtrl.dispose();
    _custPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _plateCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _showCreateForm = false;
      _hurFound = false;
      _results = [];
    });
    _results = await DiagnosticService.searchVehicles(q);
    if (_results.isEmpty) {
      setState(() => _hurLoading = true);
      final hurData = await DiagnosticService.lookupHurVehicle(q);
      if (mounted) {
        setState(() {
          _hurLoading = false;
          if (hurData != null) {
            _hurFound = true;
            _makeCtrl.text = (hurData['make'] ?? hurData['brand'] ?? '')
                .toString();
            _modelCtrl.text = (hurData['model'] ?? hurData['modelName'] ?? '')
                .toString();
            _yearCtrl.text = (hurData['year'] ?? hurData['buildYear'] ?? '')
                .toString();
            _vinCtrl.text = (hurData['vin'] ?? hurData['vinNumber'] ?? '')
                .toString();
          }
        });
      }
    }
    if (mounted) {
      setState(() {
        _searching = false;
        if (_results.isEmpty) _showCreateForm = true;
      });
    }
  }

  void _searchCustomers(String q) {
    _custSearchTimer?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _customerResults = []);
      return;
    }
    _custSearchTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      setState(() => _searchingCustomers = true);
      final results = await DiagnosticService.searchCustomers(q.trim());
      if (!mounted) return;
      setState(() {
        _customerResults = results;
        _searchingCustomers = false;
      });
    });
  }

  void _selectVehicle(VehicleSummary v) {
    final prov = context.read<NewInspectionController>();
    prov.setVehicle(v, customer: v.customer);
    _pushChecklist();
  }

  Future<void> _create() async {
    final plate = _plateCtrl.text.trim().toUpperCase();
    final make = _makeCtrl.text.trim();
    final model = _modelCtrl.text.trim();

    if (plate.isEmpty || make.isEmpty || model.isEmpty) return;

    setState(() => _creating = true);
    try {
      CustomerSummary? customer = _selectedCustomer;
      if (customer == null) {
        final custName = _custNameCtrl.text.trim();
        final custPhone = _custPhoneCtrl.text.trim();
        if (custName.isEmpty || custPhone.isEmpty) return;
        customer = await DiagnosticService.createCustomer(
          fullName: custName,
          phone: custPhone,
        );
        if (customer == null || !mounted) return;
      }

      final year = int.tryParse(_yearCtrl.text.trim());
      final mileage = int.tryParse(
        _mileageCtrl.text.trim().replaceAll(',', ''),
      );
      final vehicle = await DiagnosticService.createVehicle(
        plate: plate,
        make: make,
        model: model,
        vin: _vinCtrl.text.trim(),
        year: year,
        mileage: mileage,
        customerId: customer.id,
      );
      if (vehicle == null || !mounted) return;

      final prov = context.read<NewInspectionController>();
      prov.setVehicle(vehicle, customer: customer);
      _pushChecklist();
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _pushChecklist() {
    final prov = context.read<NewInspectionController>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: prov,
          child: const _ChecklistStep(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<NewInspectionController>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Машин хайх'),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        actions: const [ShellNotificationBell()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (prov.template != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: context.colors.accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSM),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 16,
                      color: context.colors.accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      prov.template!.name,
                      style: context.textStyles.captionMedium.copyWith(
                        color: context.colors.accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Улсын дугаар', style: context.textStyles.h3),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'Дугаар',
                          hint: 'УБ 1234 АБА',
                          controller: _plateCtrl,
                          onChanged: (_) {
                            setState(() {
                              _results = [];
                              _showCreateForm = false;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _searching ? null : _search,
                          child: _searching
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: CarCareTheme.of(context).onAccent,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text('Хайх'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // HUR loading indicator
            if (_hurLoading) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('ХУР бүртгэлд хайж байна...'),
                ],
              ),
            ],

            if (_results.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Олдсон машин(ууд)',
                style: context.textStyles.captionMedium,
              ),
              const SizedBox(height: 8),
              ..._results.map(
                (v) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    onTap: () => _selectVehicle(v),
                    child: Row(
                      children: [
                        Icon(
                          Icons.directions_car_outlined,
                          color: context.colors.accent,
                        ),
                        const SizedBox(width: 12),
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
                                  style: context.textStyles.caption,
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: context.colors.textHint,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            if (_showCreateForm) ...[
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Шинэ машин бүртгэх', style: context.textStyles.h3),
                    const SizedBox(height: 4),
                    Text(
                      'Дугаар "${_plateCtrl.text.trim().toUpperCase()}" олдсонгүй',
                      style: context.textStyles.caption,
                    ),
                    if (_hurFound) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.good.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusSM,
                          ),
                          border: Border.all(
                            color: context.colors.good.withOpacity(0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.verified_outlined,
                              color: context.colors.good,
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'ХУР-аас мэдээлэл автоматаар бөглөгдлөө',
                              style: context.textStyles.caption.copyWith(
                                color: context.colors.good,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Divider(height: 24),

                    Text(
                      'Машины мэдээлэл',
                      style: context.textStyles.captionMedium,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Марка *',
                            hint: 'Toyota',
                            controller: _makeCtrl,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppTextField(
                            label: 'Загвар *',
                            hint: 'Prius',
                            controller: _modelCtrl,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Он',
                            hint: '2018',
                            controller: _yearCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppTextField(
                            label: 'VIN',
                            hint: 'Заавал биш',
                            controller: _vinCtrl,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    AppTextField(
                      label: 'Явсан км',
                      hint: '0',
                      controller: _mileageCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                    const Divider(height: 24),

                    // ─── Customer: search first, then create ─────────────────
                    Text(
                      'Үйлчлүүлэгч',
                      style: context.textStyles.captionMedium,
                    ),
                    const SizedBox(height: 10),
                    AppTextField(
                      label: 'Нэр эсвэл утасны дугаараар хайх',
                      hint: 'Бат, 99001122...',
                      controller: _custSearchCtrl,
                      onChanged: _searchCustomers,
                      suffixIcon: _searchingCustomers
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : null,
                    ),
                    if (_customerResults.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ..._customerResults
                          .take(5)
                          .map(
                            (c) => GestureDetector(
                              onTap: () => setState(() {
                                _selectedCustomer = c;
                                _customerResults = [];
                                _custSearchCtrl.clear();
                              }),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: context.colors.surface,
                                  borderRadius: BorderRadius.circular(
                                    AppDimens.radiusSM,
                                  ),
                                  border: Border.all(
                                    color: context.colors.divider,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline,
                                      color: context.colors.textSecondary,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.displayName,
                                            style:
                                                context.textStyles.bodyMedium,
                                          ),
                                          Text(
                                            c.phone,
                                            style: context.textStyles.caption,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.add,
                                      color: context.colors.accent,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                    ],
                    if (_selectedCustomer != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.accent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusSM,
                          ),
                          border: Border.all(
                            color: context.colors.accent.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: context.colors.accent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedCustomer!.displayName,
                                    style: context.textStyles.bodyMedium
                                        .copyWith(color: context.colors.accent),
                                  ),
                                  Text(
                                    _selectedCustomer!.phone,
                                    style: context.textStyles.caption,
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedCustomer = null),
                              child: Icon(
                                Icons.close,
                                color: context.colors.textSecondary,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'эсвэл шинээр бүртгэх',
                              style: context.textStyles.caption,
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 10),
                      AppTextField(
                        label: 'Овог нэр *',
                        hint: 'Бат',
                        controller: _custNameCtrl,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),
                      AppTextField(
                        label: 'Утасны дугаар *',
                        hint: '99001122',
                        controller: _custPhoneCtrl,
                        keyboardType: TextInputType.phone,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        label: _creating
                            ? 'Бүртгэж байна...'
                            : 'Бүртгэж үргэлжлүүлэх',
                        onPressed: _canCreate && !_creating ? _create : null,
                        loading: _creating,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  bool get _canCreate =>
      _plateCtrl.text.trim().isNotEmpty &&
      _makeCtrl.text.trim().isNotEmpty &&
      _modelCtrl.text.trim().isNotEmpty &&
      (_selectedCustomer != null ||
          (_custNameCtrl.text.trim().isNotEmpty &&
              _custPhoneCtrl.text.trim().isNotEmpty));
}

// ─── АЛХАМ 2: Динамик checklist ───────────────────────────────────────────────

class _ChecklistStep extends StatefulWidget {
  const _ChecklistStep();

  @override
  State<_ChecklistStep> createState() => _ChecklistStepState();
}

class _ChecklistStepState extends State<_ChecklistStep> {
  // Асуултын үгээр хайх (web diagnostic-form-тай ижил). Хариулт controller-т
  // хадгалагддаг тул тохирохгүй мөрийг жагсаалтаас хасахад алдагдахгүй.
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<NewInspectionController>();
    final sections = prov.sections;

    final children = <Widget>[];
    for (final section in sections) {
      final visible = section.items.where(prov.isItemVisible).toList();
      if (visible.isEmpty) continue;
      final matching = _q.isEmpty
          ? visible
          : visible.where((i) => i.label.toLowerCase().contains(_q)).toList();
      if (matching.isEmpty) continue;
      children.add(
        _SectionHeader(
          title: section.title,
          options: prov.bulkOptionsFor([section]),
          onMark: (v) => prov.markAll(v, [section]),
        ),
      );
      for (final item in matching) {
        children.add(
          KeyedSubtree(
            key: ValueKey(item.id),
            child: _ItemWidget(item: item, prov: prov),
          ),
        );
      }
    }

    final globalOptions = prov.bulkOptionsFor();

    return Scaffold(
      appBar: AppBar(
        title: Text(prov.template?.name ?? 'Оношилгоо'),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        actions: const [ShellNotificationBell()],
      ),
      body: sections.isEmpty
          ? const Center(child: Text('Хэсэг байхгүй'))
          : Column(
              children: [
                Container(
                  color: context.colors.surface,
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.paddingMD,
                    12,
                    AppDimens.paddingMD,
                    12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _search,
                        onChanged: (v) =>
                            setState(() => _q = v.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'Асуулт хайх',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          suffixIcon: _q.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Цэвэрлэх',
                                  icon: const Icon(Icons.close),
                                  onPressed: () => setState(() {
                                    _search.clear();
                                    _q = '';
                                  }),
                                ),
                        ),
                      ),
                      if (globalOptions.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _BulkButtons(
                          label: 'Бүх хэсгийг:',
                          options: globalOptions,
                          onMark: prov.markAll,
                        ),
                      ],
                    ],
                  ),
                ),

                Expanded(
                  child: children.isEmpty
                      ? Center(
                          child: Text(
                            '«${_search.text.trim()}» гэсэн асуулт олдсонгүй.',
                            style: context.textStyles.caption,
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(AppDimens.paddingMD),
                          children: children,
                        ),
                ),

                Container(
                  padding: const EdgeInsets.all(AppDimens.paddingMD),
                  color: context.colors.surface,
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Буцах',
                            outlined: true,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppButton(
                            label: 'Дуусгах',
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChangeNotifierProvider.value(
                                  value: prov,
                                  child: const _NoteStep(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final List<String> options;
  final ValueChanged<String> onMark;
  const _SectionHeader({
    required this.title,
    required this.options,
    required this.onMark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          Text(title, style: context.textStyles.h3),
          if (options.isNotEmpty)
            _BulkButtons(label: 'Бүгдийг:', options: options, onMark: onMark),
        ],
      ),
    );
  }
}

class _BulkButtons extends StatelessWidget {
  final String label;
  final List<String> options;
  final ValueChanged<String> onMark;
  const _BulkButtons({
    required this.label,
    required this.options,
    required this.onMark,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        Text(label, style: context.textStyles.caption),
        for (final opt in options)
          ActionChip(
            label: Text(opt),
            visualDensity: VisualDensity.compact,
            onPressed: () => onMark(opt),
          ),
      ],
    );
  }
}

class _ItemWidget extends StatelessWidget {
  final TemplateItem item;
  final NewInspectionController prov;
  const _ItemWidget({required this.item, required this.prov});

  @override
  Widget build(BuildContext context) {
    // Positioned item — байрлал тус бүрд тусдаа input
    if (item.positionSet != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _PositionedItemWidget(item: item, prov: prov),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.label + (item.required ? ' *' : ''),
                    style: context.textStyles.bodyMedium,
                  ),
                ),
                if (item.type == ItemType.check) ...[
                  const SizedBox(width: 8),
                  _CheckStatusBadge(value: prov.getAnswer(item.id)),
                ],
              ],
            ),
            const SizedBox(height: 10),

            if (item.type == ItemType.check)
              _CheckInput(item: item, prov: prov, fieldKey: item.id),
            if (item.type == ItemType.text)
              _TextInput(item: item, prov: prov, fieldKey: item.id),
            if (item.type == ItemType.number)
              _NumberInput(item: item, prov: prov, fieldKey: item.id),
            if (item.type == ItemType.photo)
              _PhotoInput(item: item, prov: prov, fieldKey: item.id),
            if (item.type == ItemType.signature)
              Text(
                '(Гарын үсэг — тэмдэглэл орлуулна)',
                style: context.textStyles.caption,
              ),

            if (item.type != ItemType.photo &&
                item.type != ItemType.signature) ...[
              const SizedBox(height: 8),
              _NoteField(prov: prov, fieldKey: item.id),
            ],
          ],
        ),
      ),
    );
  }
}

// Positioned item — байрлал тус бүр нь тусдаа мөр
class _PositionedItemWidget extends StatelessWidget {
  final TemplateItem item;
  final NewInspectionController prov;
  const _PositionedItemWidget({required this.item, required this.prov});

  @override
  Widget build(BuildContext context) {
    final positions = item.positionSet!.positions;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label + (item.required ? ' *' : ''),
            style: context.textStyles.bodyMedium,
          ),
          const SizedBox(height: 12),
          ...positions.asMap().entries.map((entry) {
            final i = entry.key;
            final pos = entry.value;
            final key = positionedKey(item.id, pos.code);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (i > 0) const Divider(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(AppDimens.radiusSM),
                      ),
                      child: Text(
                        pos.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: context.colors.accent,
                        ),
                      ),
                    ),
                    if (item.type == ItemType.check) ...[
                      const SizedBox(width: 8),
                      _CheckStatusBadge(value: prov.getAnswer(key)),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                if (item.type == ItemType.check)
                  _CheckInput(item: item, prov: prov, fieldKey: key),
                if (item.type == ItemType.text)
                  _TextInput(item: item, prov: prov, fieldKey: key),
                if (item.type == ItemType.number)
                  _NumberInput(item: item, prov: prov, fieldKey: key),
                if (item.type == ItemType.photo)
                  _PhotoInput(item: item, prov: prov, fieldKey: key),
                if (item.type != ItemType.signature) ...[
                  const SizedBox(height: 6),
                  _NoteField(prov: prov, fieldKey: key),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _CheckStatusBadge extends StatelessWidget {
  final String? value;
  const _CheckStatusBadge({this.value});

  @override
  Widget build(BuildContext context) {
    if (value == null) return const SizedBox.shrink();
    CheckStatus status;
    if (value == 'Засах') {
      status = CheckStatus.danger;
    } else if (value == 'Анхаарах') {
      status = CheckStatus.warning;
    } else {
      status = CheckStatus.good;
    }
    return StatusBadge(status: status, compact: true);
  }
}

class _CheckInput extends StatelessWidget {
  final TemplateItem item;
  final NewInspectionController prov;
  final String fieldKey;
  const _CheckInput({
    required this.item,
    required this.prov,
    required this.fieldKey,
  });

  @override
  Widget build(BuildContext context) {
    final options = item.effectiveOptions;
    final selected = prov.getAnswer(fieldKey);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = selected == opt;
        Color color;
        if (opt == 'Засах') {
          color = context.colors.danger;
        } else if (opt == 'Анхаарах') {
          color = context.colors.warning;
        } else {
          color = context.colors.good;
        }

        return GestureDetector(
          onTap: () => prov.setAnswer(fieldKey, opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withOpacity(0.12)
                  : context.colors.background,
              borderRadius: BorderRadius.circular(AppDimens.radiusFull),
              border: Border.all(
                color: isSelected ? color : context.colors.divider,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              opt,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? color : context.colors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TextInput extends StatelessWidget {
  final TemplateItem item;
  final NewInspectionController prov;
  final String fieldKey;
  const _TextInput({
    required this.item,
    required this.prov,
    required this.fieldKey,
  });

  @override
  Widget build(BuildContext context) {
    return _ControlledTextField(
      key: ValueKey('answer:$fieldKey'),
      initialText: prov.getAnswer(fieldKey) ?? '',
      onChanged: (v) => prov.setAnswer(fieldKey, v),
      decoration: const InputDecoration(hintText: 'Утга оруулна уу...'),
      style: context.textStyles.body,
    );
  }
}

class _NumberInput extends StatelessWidget {
  final TemplateItem item;
  final NewInspectionController prov;
  final String fieldKey;
  const _NumberInput({
    required this.item,
    required this.prov,
    required this.fieldKey,
  });

  @override
  Widget build(BuildContext context) {
    return _ControlledTextField(
      key: ValueKey('answer:$fieldKey'),
      initialText: prov.getAnswer(fieldKey) ?? '',
      onChanged: (v) => prov.setAnswer(fieldKey, v),
      decoration: const InputDecoration(hintText: '0'),
      style: context.textStyles.body,
      keyboardType: TextInputType.number,
    );
  }
}

/// Controller-ийг State дотор нэг л удаа үүсгэнэ. build бүрт шинэ
/// TextEditingController үүсгэвэл курсор 0 руу үсэрч, бичсэн үг урвуу гардаг.
class _ControlledTextField extends StatefulWidget {
  final String initialText;
  final ValueChanged<String> onChanged;
  final InputDecoration decoration;
  final TextStyle? style;
  final TextInputType? keyboardType;
  const _ControlledTextField({
    super.key,
    required this.initialText,
    required this.onChanged,
    required this.decoration,
    this.style,
    this.keyboardType,
  });

  @override
  State<_ControlledTextField> createState() => _ControlledTextFieldState();
}

class _ControlledTextFieldState extends State<_ControlledTextField> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      decoration: widget.decoration,
      style: widget.style,
      keyboardType: widget.keyboardType,
      onChanged: widget.onChanged,
    );
  }
}

// ─── АЛХАМ 3: Нэмэлт мэдээлэл + илгээх ──────────────────────────────────────

class _NoteStep extends StatefulWidget {
  const _NoteStep();

  @override
  State<_NoteStep> createState() => _NoteStepState();
}

class _NoteStepState extends State<_NoteStep> {
  final _mileageCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<NewInspectionController>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Нэмэлт мэдээлэл'),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        actions: const [ShellNotificationBell()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.paddingMD),
        children: [
          // ─── Дүн ────────────────────────────────────────────────────────
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Оношилгооны дүн', style: context.textStyles.h3),
                const SizedBox(height: 12),
                StatCounterRow(
                  good: prov.answeredGood,
                  warning: prov.answeredWarning,
                  danger: prov.answeredDanger,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ─── Машины мэдээлэл ─────────────────────────────────────────────
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Машин', style: context.textStyles.h3),
                const SizedBox(height: 10),
                if (prov.vehicle != null) ...[
                  _SummaryRow(label: 'Дугаар', value: prov.vehicle!.plate),
                  _SummaryRow(label: 'Марка', value: prov.vehicle!.displayName),
                ],
                if (prov.customer != null)
                  _SummaryRow(
                    label: 'Үйлчлүүлэгч',
                    value: prov.customer!.displayName,
                  ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Явсан км',
                  hint: '0',
                  controller: _mileageCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      prov.setMileage(int.tryParse(v.replaceAll(',', '')) ?? 0),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ─── Тайлбар ─────────────────────────────────────────────────────
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Нийт тайлбар', style: context.textStyles.h3),
                const SizedBox(height: 10),
                TextField(
                  controller: _noteCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Нэмэлт тайлбар...',
                  ),
                  style: context.textStyles.body,
                  onChanged: prov.setGeneralNote,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── Илгээх товч ─────────────────────────────────────────────────
          AppButton(
            label: prov.submitting ? 'Илгээж байна...' : 'Тайлан илгээх',
            onPressed: prov.submitting ? null : () => _submit(context),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final prov = context.read<NewInspectionController>();
    final user = Authenticator.user;
    // Working branch first — the server 403s a report filed under a branch
    // other than the `X-Working-Branch` scope.
    final branchId = workingBranchIdOf(context) ?? user?.branchId ?? '';

    if (branchId.isEmpty) {
      // Салбар байхгүй бол эхний салбарыг авна
      final branches = await DiagnosticService.getBranches();
      if (branches.isEmpty) {
        return;
      }
      final id = await prov.submit(branches.first.id);
      if (!context.mounted) return;
      _onSuccess(context, prov, id);
    } else {
      final id = await prov.submit(branchId);
      if (!context.mounted) return;
      _onSuccess(context, prov, id);
    }
  }

  void _onSuccess(
    BuildContext context,
    NewInspectionController prov,
    String? reportId,
  ) {
    if (reportId == null) return;
    // InspectionController-г reload хийнэ
    context.read<InspectionController>().loadReports();
    // Дэлгэрэнгүй дэлгэц рүү шилжинэ
    // Захиалгаас нээсэн бол зөвхөн маягтын алхмуудыг хаана — back дарахад
    // тухайн захиалгын дэлгэрэнгүй рүү буцна. Үгүй бол эхний дэлгэц хүртэл.
    var passedForm = false;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => ReportDetailScreen(reportId: reportId)),
      (route) {
        if (route.isFirst || passedForm) return true;
        if (prov.fromOrder && route.settings.name == _orderFormRouteName) {
          passedForm = true;
        }
        return false;
      },
    );
  }
}

const _orderFormRouteName = 'order-diagnostic-form';

// ─── Photo input widget ────────────────────────────────────────────────────────

class _PhotoInput extends StatefulWidget {
  final TemplateItem item;
  final NewInspectionController prov;
  final String fieldKey;
  const _PhotoInput({
    required this.item,
    required this.prov,
    required this.fieldKey,
  });

  @override
  State<_PhotoInput> createState() => _PhotoInputState();
}

class _PhotoInputState extends State<_PhotoInput> {
  final _picker = ImagePicker();

  Future<void> _pick() async {
    final picked = await _picker.pickMultiImage(
      imageQuality: uploadImageQuality,
      maxWidth: uploadMaxDimension,
      maxHeight: uploadMaxDimension,
    );
    final images = await filterUploadable(picked);
    for (final img in images.accepted) {
      widget.prov.addPhoto(widget.fieldKey, img.path);
    }
    if (images.rejected > 0) messageWarning(uploadTooLargeMessage);
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.prov.getPhotos(widget.fieldKey);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...photos.asMap().entries.map(
          (e) => Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimens.radiusSM),
                child: Image.file(
                  File(e.value),
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () => widget.prov.removePhoto(widget.fieldKey, e.key),
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.colors.textPrimary.withOpacity(0.54),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      color: context.colors.background,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: _pick,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(AppDimens.radiusSM),
              border: Border.all(color: context.colors.divider),
            ),
            child: Icon(
              Icons.add_a_photo_outlined,
              color: context.colors.textHint,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Note field ───────────────────────────────────────────────────────────────

class _NoteField extends StatelessWidget {
  final NewInspectionController prov;
  final String fieldKey;
  const _NoteField({required this.prov, required this.fieldKey});

  @override
  Widget build(BuildContext context) {
    return _ControlledTextField(
      key: ValueKey('note:$fieldKey'),
      initialText: prov.getNote(fieldKey) ?? '',
      onChanged: (v) => prov.setNote(fieldKey, v),
      decoration: const InputDecoration(
        hintText: 'Тайлбар (заавал биш)...',
        isDense: true,
      ),
      style: context.textStyles.caption.copyWith(
        color: context.colors.textPrimary,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: context.textStyles.caption),
          ),
          Expanded(child: Text(value, style: context.textStyles.bodyMedium)),
        ],
      ),
    );
  }
}
