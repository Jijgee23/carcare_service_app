import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:carcare_service/core/theme/app_theme.dart';
import 'package:carcare_service/features/models/appointment.dart';
import 'package:carcare_service/features/models/diagnostic.dart';
import 'package:carcare_service/features/presentation/controllers/create_appointment_controller.dart';
import 'package:carcare_service/shared/widgets/dialogs/message.dart';
import 'package:carcare_service/shared/widgets/mn_date_picker.dart';

class CreateAppointmentScreen extends StatelessWidget {
  const CreateAppointmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CreateAppointmentController()..init(),
      child: const _Body(),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<CreateAppointmentController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Цаг захиалга үүсгэх')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 1. Огноо, цаг ─────────────────────────────────────
                  _SectionLabel(number: '1', title: 'Огноо, цаг', done: true),
                  const SizedBox(height: 10),
                  _DateTimeSection(ctrl: ctrl),
                  const SizedBox(height: 24),

                  // ── 2. Хэрэглэгч ──────────────────────────────────────
                  _SectionLabel(
                    number: '2',
                    title: 'Хэрэглэгч',
                    done:
                        ctrl.selectedCustomer != null ||
                        (ctrl.isWalkIn && ctrl.walkInPhoneCtrl.text.trim().isNotEmpty),
                  ),
                  const SizedBox(height: 10),
                  _CustomerSection(ctrl: ctrl),
                  const SizedBox(height: 24),

                  // ── 3. Машин ───────────────────────────────────────────
                  _SectionLabel(
                    number: '3',
                    title: 'Машин',
                    done: ctrl.selectedVehicle != null,
                    optional: true,
                  ),
                  const SizedBox(height: 10),
                  _VehicleSection(ctrl: ctrl),
                  const SizedBox(height: 24),

                  // ── 4. Салбар ──────────────────────────────────────────
                  _SectionLabel(number: '4', title: 'Салбар', done: ctrl.selectedBranch != null),
                  const SizedBox(height: 10),
                  _BranchSection(ctrl: ctrl),
                  const SizedBox(height: 24),

                  // ── 5. Тэмдэглэл ───────────────────────────────────────
                  _SectionLabel(number: '5', title: 'Тэмдэглэл', optional: true, done: false),
                  const SizedBox(height: 10),
                  _NoteSection(ctrl: ctrl),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          _BottomBar(ctrl: ctrl),
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
            color: done ? AppColors.good : AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                : Text(
                    number,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTextStyles.h3.copyWith(color: done ? AppColors.good : AppColors.textPrimary),
        ),
        if (optional) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'заавал биш',
              style: TextStyle(fontSize: 10, color: AppColors.textHint),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Date/time section ─────────────────────────────────────────────────────────

class _DateTimeSection extends StatelessWidget {
  final CreateAppointmentController ctrl;
  const _DateTimeSection({required this.ctrl});

  static final _fmt = DateFormat('yyyy-MM-dd HH:mm');

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusMD),
          border: Border.all(color: AppColors.accent.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppDimens.radiusSM),
              ),
              child: const Icon(Icons.event_rounded, color: AppColors.accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Товлосон цаг',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(_fmt.format(ctrl.requestedAt), style: AppTextStyles.h3),
                ],
              ),
            ),
            const Icon(Icons.edit_calendar_rounded, size: 18, color: AppColors.accent),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final result = await showMnDateTimePicker(
      context,
      initial: ctrl.requestedAt,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (result != null) ctrl.setRequestedAt(result);
  }
}

// ─── Customer section ──────────────────────────────────────────────────────────

class _CustomerSection extends StatelessWidget {
  final CreateAppointmentController ctrl;
  const _CustomerSection({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    // Selected customer card
    if (ctrl.selectedCustomer != null) {
      return _SelectedCustomerCard(ctrl: ctrl);
    }

    // Walk-in mode
    if (ctrl.isWalkIn) {
      return _WalkInForm(ctrl: ctrl);
    }

    // Search mode
    return Column(
      children: [
        // Search field
        _SearchField(
          controller: ctrl.customerSearchCtrl,
          hint: 'Нэр эсвэл утасны дугаараар хайх...',
          icon: Icons.person_search_rounded,
          loading: ctrl.searchingCustomer,
          onChanged: ctrl.searchCustomer,
          onClear: () {
            ctrl.customerSearchCtrl.clear();
            ctrl.searchCustomer('');
          },
        ),

        // Results
        if (ctrl.customerResults.isNotEmpty) ...[
          const SizedBox(height: 8),
          _CustomerResults(ctrl: ctrl),
        ],

        const SizedBox(height: 10),

        // Walk-in toggle
        GestureDetector(
          onTap: () => ctrl.setWalkIn(true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimens.radiusMD),
              border: Border.all(color: AppColors.accent.withOpacity(0.35)),
            ),
            child: const Row(
              children: [
                Icon(Icons.person_add_rounded, size: 18, color: AppColors.accent),
                SizedBox(width: 10),
                Text(
                  'Бүртгэлгүй хэрэглэгч (утасны дугаар)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
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

class _SelectedCustomerCard extends StatelessWidget {
  final CreateAppointmentController ctrl;
  const _SelectedCustomerCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final c = ctrl.selectedCustomer!;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMD),
        border: Border.all(color: AppColors.accent.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                (c.displayName.isNotEmpty ? c.displayName[0] : '?').toUpperCase(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.displayName, style: AppTextStyles.bodyMedium),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 12, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text(c.phone, style: AppTextStyles.caption),
                    if (c.email != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          c.email!,
                          style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: ctrl.clearCustomer,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalkInForm extends StatelessWidget {
  final CreateAppointmentController ctrl;
  const _WalkInForm({required this.ctrl});

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
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Phone
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: TextField(
              controller: ctrl.walkInPhoneCtrl,
              keyboardType: TextInputType.phone,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                labelText: 'Утасны дугаар *',
                labelStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.phone_rounded, size: 18, color: AppColors.textHint),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.accent, width: 1.5),
                ),
              ),
            ),
          ),

          const Divider(height: 1, indent: 14, endIndent: 14),

          // Name
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            child: TextField(
              controller: ctrl.walkInNameCtrl,
              style: AppTextStyles.body,
              decoration: const InputDecoration(
                labelText: 'Нэр (заавал биш)',
                labelStyle: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                prefixIcon: Icon(Icons.person_outline_rounded, size: 18, color: AppColors.textHint),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.accent, width: 1.5),
                ),
              ),
            ),
          ),

          const Divider(height: 1),

          // Cancel walk-in
          TextButton.icon(
            onPressed: () => ctrl.setWalkIn(false),
            icon: const Icon(Icons.arrow_back, size: 14),
            label: const Text('Бүртгэлтэй хэрэглэгч хайх'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerResults extends StatelessWidget {
  final CreateAppointmentController ctrl;
  const _CustomerResults({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final results = ctrl.customerResults;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMD),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: results.take(5).toList().asMap().entries.map((e) {
          final i = e.key;
          final c = e.value;
          final isLast = i == results.length - 1 || i == 4;
          return InkWell(
            onTap: () => ctrl.selectCustomer(c),
            borderRadius: BorderRadius.vertical(
              top: i == 0 ? const Radius.circular(AppDimens.radiusMD) : Radius.zero,
              bottom: isLast ? const Radius.circular(AppDimens.radiusMD) : Radius.zero,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                border: !isLast ? const Border(bottom: BorderSide(color: AppColors.divider)) : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        (c.displayName.isNotEmpty ? c.displayName[0] : '?').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.displayName, style: AppTextStyles.bodyMedium),
                        Text(c.phone, style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Vehicle section ───────────────────────────────────────────────────────────

class _VehicleSection extends StatelessWidget {
  final CreateAppointmentController ctrl;
  const _VehicleSection({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    // Selected vehicle
    if (ctrl.selectedVehicle != null) {
      return _SelectedVehicleCard(ctrl: ctrl);
    }

    return Column(
      children: [
        _SearchField(
          controller: ctrl.vehicleSearchCtrl,
          hint: 'Улсын дугаараар хайх...',
          icon: Icons.directions_car_rounded,
          loading: ctrl.searchingVehicle,
          onChanged: ctrl.searchVehicle,
          onClear: () {
            ctrl.vehicleSearchCtrl.clear();
            ctrl.searchVehicle('');
          },
          capitalize: true,
        ),
        if (ctrl.vehicleResults.isNotEmpty) ...[
          const SizedBox(height: 8),
          _VehicleResults(ctrl: ctrl),
        ],
      ],
    );
  }
}

class _SelectedVehicleCard extends StatelessWidget {
  final CreateAppointmentController ctrl;
  const _SelectedVehicleCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final v = ctrl.selectedVehicle!;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMD),
        border: Border.all(color: AppColors.good.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.good.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.good.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDimens.radiusSM),
            ),
            child: const Icon(Icons.directions_car_rounded, color: AppColors.good, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.plate, style: AppTextStyles.h3.copyWith(color: AppColors.good)),
                const SizedBox(height: 2),
                Text(v.displayName, style: AppTextStyles.caption),
                if (v.customer != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 12, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text(v.customer!.displayName, style: AppTextStyles.caption),
                    ],
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: ctrl.clearVehicle,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleResults extends StatelessWidget {
  final CreateAppointmentController ctrl;
  const _VehicleResults({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final results = ctrl.vehicleResults;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMD),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: results.take(5).toList().asMap().entries.map((e) {
          final i = e.key;
          final v = e.value;
          final isLast = i == results.length - 1 || i == 4;
          return InkWell(
            onTap: () => ctrl.selectVehicle(v),
            borderRadius: BorderRadius.vertical(
              top: i == 0 ? const Radius.circular(AppDimens.radiusMD) : Radius.zero,
              bottom: isLast ? const Radius.circular(AppDimens.radiusMD) : Radius.zero,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                border: !isLast ? const Border(bottom: BorderSide(color: AppColors.divider)) : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(AppDimens.radiusSM),
                    ),
                    child: const Icon(
                      Icons.directions_car_outlined,
                      color: AppColors.accent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v.plate, style: AppTextStyles.bodyMedium),
                        Text(v.displayName, style: AppTextStyles.caption),
                        if (v.customer != null)
                          Text(
                            v.customer!.displayName,
                            style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Branch section ─────────────────────────────────────────────────────────────

class _BranchSection extends StatelessWidget {
  final CreateAppointmentController ctrl;
  const _BranchSection({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    if (ctrl.loadingBranches) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusMD),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Text('Салбаруудыг ачааллаж байна...', style: AppTextStyles.caption),
          ],
        ),
      );
    }

    if (ctrl.branches.length == 1) {
      final b = ctrl.branches.first;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusMD),
          border: Border.all(color: AppColors.good.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(
              color: AppColors.good.withOpacity(0.06),
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
                color: AppColors.good.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppDimens.radiusSM),
              ),
              child: const Icon(Icons.storefront_rounded, color: AppColors.good, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.name, style: AppTextStyles.bodyMedium),
                  if (b.address != null) Text(b.address!, style: AppTextStyles.caption),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.good.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppDimens.radiusFull),
              ),
              child: const Text(
                'Автомат',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.good),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMD),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: ctrl.branches.asMap().entries.map((e) {
          final i = e.key;
          final b = e.value;
          final isSelected = b.id == ctrl.selectedBranch?.id;
          final isLast = i == ctrl.branches.length - 1;
          return InkWell(
            onTap: () => ctrl.selectBranch(b),
            borderRadius: BorderRadius.vertical(
              top: i == 0 ? const Radius.circular(AppDimens.radiusMD) : Radius.zero,
              bottom: isLast ? const Radius.circular(AppDimens.radiusMD) : Radius.zero,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accent.withOpacity(0.06) : Colors.transparent,
                borderRadius: BorderRadius.vertical(
                  top: i == 0 ? const Radius.circular(AppDimens.radiusMD) : Radius.zero,
                  bottom: isLast ? const Radius.circular(AppDimens.radiusMD) : Radius.zero,
                ),
                border: !isLast ? const Border(bottom: BorderSide(color: AppColors.divider)) : null,
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? AppColors.accent : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? AppColors.accent : AppColors.divider,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.name,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isSelected ? AppColors.accent : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                        if (b.address != null) Text(b.address!, style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.accent),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Note section ──────────────────────────────────────────────────────────────

class _NoteSection extends StatelessWidget {
  final CreateAppointmentController ctrl;
  const _NoteSection({required this.ctrl});

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
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppDimens.radiusSM),
              ),
              child: const Icon(Icons.notes_rounded, size: 18, color: AppColors.textHint),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: ctrl.noteCtrl,
              maxLines: 3,
              style: AppTextStyles.body,
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
    );
  }
}

// ─── Shared search field ───────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool loading;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool capitalize;

  const _SearchField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.loading,
    required this.onChanged,
    required this.onClear,
    this.capitalize = false,
  });

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
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        textCapitalization: capitalize ? TextCapitalization.characters : TextCapitalization.none,
        onChanged: onChanged,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.textHint, size: 20),
          suffixIcon: loading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppColors.textHint),
                  onPressed: onClear,
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
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
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
          ),
        ),
      ),
    );
  }
}

// ─── Bottom bar ─────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final CreateAppointmentController ctrl;
  const _BottomBar({required this.ctrl});

  static final _fmt = DateFormat('yyyy-MM-dd HH:mm');

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final can = ctrl.canSubmit;

    String? hint;
    if (ctrl.selectedBranch == null) {
      hint = 'Салбар сонгоогүй байна';
    } else if (!ctrl.isWalkIn && ctrl.selectedCustomer == null) {
      hint = 'Хэрэглэгч сонгоогүй байна';
    } else if (ctrl.isWalkIn && ctrl.walkInPhoneCtrl.text.trim().isEmpty) {
      hint = 'Утасны дугаар оруулна уу';
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Summary row
          if (can) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppDimens.radiusSM),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_rounded, size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 5),
                  Text(_fmt.format(ctrl.requestedAt), style: AppTextStyles.captionMedium),
                  const SizedBox(width: 8),
                  const Icon(Icons.person_outline, size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      ctrl.isWalkIn
                          ? ctrl.walkInPhoneCtrl.text.trim()
                          : ctrl.selectedCustomer!.displayName,
                      style: AppTextStyles.captionMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Missing hint
          if (hint != null) ...[
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.warning),
                const SizedBox(width: 6),
                Text(
                  hint,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.warning,
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
            child: can
                ? Material(
                    borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: ctrl.submitting
                            ? null
                            : LinearGradient(
                                colors: [AppColors.accent, AppColors.accent.withBlue(220)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                        color: ctrl.submitting ? AppColors.accent.withOpacity(0.6) : null,
                        borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                        boxShadow: ctrl.submitting
                            ? null
                            : [
                                BoxShadow(
                                  color: AppColors.accent.withOpacity(0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: InkWell(
                        onTap: ctrl.submitting ? null : () => _submit(context),
                        borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                        child: Center(
                          child: ctrl.submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Цаг захиалга үүсгэх',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
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
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(AppDimens.radiusMD),
                    ),
                    child: const Center(
                      child: Text(
                        'Цаг захиалга үүсгэх',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textHint,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final ctrl = context.read<CreateAppointmentController>();
    final result = await ctrl.submit();
    if (result != null && context.mounted) {
      messageComplete('Цаг захиалга амжилттай үүслээ');
      Navigator.pop(context, result);
    }
  }
}
