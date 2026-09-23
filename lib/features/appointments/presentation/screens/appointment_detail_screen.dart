import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:carcare_service/app/router.dart';
import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/core/widgets/dialogs/confirm_sheet.dart';
import 'package:carcare_service/core/widgets/dialogs/message.dart';
import 'package:carcare_service/features/appointments/domain/appointment.dart';
import 'package:carcare_service/features/appointments/domain/appointments_repository.dart';
import 'package:carcare_service/features/appointments/presentation/controllers/appointment_detail_controller.dart';
import 'package:carcare_service/features/appointments/presentation/widgets/appointment_payment_widgets.dart';
import 'package:carcare_service/features/orders/data/order_repository.dart';
import 'package:carcare_service/features/orders/domain/orders_repository.dart';
import 'package:carcare_service/features/orders/presentation/feature_theme.dart';

/// Builds the canonical nested Orders detail route for an appointment link.
/// Keep the id encoded: order ids are server data, not route syntax.
String appointmentOrderRoute(String orderId) =>
    '${AppRoutes.orders}/${Uri.encodeComponent(orderId)}';

/// Appointment detail, lifecycle and payments screen — P2-F5.
///
/// Constructed with the [initial] `AppointmentSummary` the caller already
/// has (from the list row or a calendar block tap) rather than an id alone —
/// the frozen `AppointmentsRepository` contract (P2-F1) has no
/// single-appointment GET, only the paged day-list. [refresh] on the
/// controller is a best-effort re-fetch of that same day/branch page; it
/// never blocks the initial render and never replaces a successful mutation
/// with an error state (see `appointment_detail_controller.dart`).
///
/// Every action button here is a UX hint only: it is gated by the caller's
/// permission (hides the control) and by `AppointmentStatus.nextStatuses` /
/// the mirrored arrived/reschedule preconditions (disables the control) —
/// never the final word. A server rejection of an action this screen thought
/// legal is shown verbatim via `error.display`, never replaced by
/// client-authored copy.
class AppointmentDetailScreen extends StatefulWidget {
  const AppointmentDetailScreen({
    super.key,
    required this.initial,
    this.repo,
    this.ordersRepository,
    this.user,
  });

  final AppointmentSummary initial;
  final AppointmentsRepository? repo;
  final OrdersRepository? ordersRepository;
  final User? user;

  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  User? get _user => widget.user ?? Authenticator.user;

  bool _canEdit(User? user) =>
      user?.isOwner == true ||
      user?.role?.permissions.contains('appointments.edit') == true;

  bool _canViewPayments(User? user) =>
      user?.isOwner == true ||
      user?.role?.permissions.contains('payments.view') == true;

  bool _canEditPayments(User? user) =>
      user?.isOwner == true ||
      user?.role?.permissions.contains('payments.edit') == true;

  bool _canRefund(User? user) =>
      user?.isOwner == true ||
      user?.role?.permissions.contains('payments.delete') == true;

  bool _canCreateOrder(User? user) =>
      user?.isOwner == true ||
      user?.role?.permissions.contains('orders.create') == true;

  bool _canViewOrders(User? user) =>
      user?.isOwner == true ||
      user?.role?.permissions.contains('orders.view') == true;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppointmentDetailController>(
      create: (_) => AppointmentDetailController(
        initial: widget.initial,
        repo: widget.repo,
        ordersRepository: widget.ordersRepository ?? RemoteOrdersRepository(),
      ),
      child: _AppointmentDetailBody(
        canEdit: _canEdit(_user),
        canViewPayments: _canViewPayments(_user),
        canEditPayments: _canEditPayments(_user),
        canRefund: _canRefund(_user),
        canCreateOrder: _canCreateOrder(_user),
        canViewOrders: _canViewOrders(_user),
      ),
    );
  }
}

class _AppointmentDetailBody extends StatelessWidget {
  const _AppointmentDetailBody({
    required this.canEdit,
    required this.canViewPayments,
    required this.canEditPayments,
    required this.canRefund,
    required this.canCreateOrder,
    required this.canViewOrders,
  });

  final bool canEdit;
  final bool canViewPayments;
  final bool canEditPayments;
  final bool canRefund;
  final bool canCreateOrder;
  final bool canViewOrders;

  Future<void> _run(
    BuildContext context,
    Future<Result<Object?>> Function() action,
  ) async {
    final result = await action();
    if (!context.mounted) return;
    if (result case Err(:final error)) messageError(error.display);
  }

  Future<void> _cancel(BuildContext context) async {
    final ok = await ConfirmSheet.show(
      context,
      title: 'Цаг цуцлах уу?',
      message: 'Цуцалсны дараа буцаах боломжгүй.',
      confirmLabel: 'Цуцлах',
      isDangerous: true,
      icon: Icons.event_busy_outlined,
    );
    if (!ok || !context.mounted) return;
    await _run(
      context,
      () => context.read<AppointmentDetailController>().cancel(),
    );
  }

  Future<void> _reschedule(BuildContext context) async {
    final controller = context.read<AppointmentDetailController>();
    final appointment = controller.appointment;
    if (appointment == null) return;
    final now = DateTime.now();
    final base = appointment.requestedAt ?? now;
    final firstDate = DateTime(now.year, now.month, now.day);
    final lastDate = DateTime(now.year, now.month, now.day + 365);
    final initialDate = base.isBefore(firstDate) ? firstDate : base;
    final date = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: initialDate,
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null || !context.mounted) return;
    final next = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    // D-111: no capacity/overlap confirmation dialog here — that step was
    // deliberately removed server-side. Only the server's working-hours
    // validation applies; a rejection surfaces via `error.display` below,
    // unmodified.
    final result = await controller.reschedule(next);
    if (!context.mounted) return;
    if (result case Err(:final error)) messageError(error.display);
  }

  Future<void> _refund(BuildContext context) async {
    final controller = context.read<AppointmentDetailController>();
    // Controller-free dialog input: a local `String` closed over by
    // `onChanged`, not a `TextEditingController` owned by this short-lived
    // dialog — the same pattern `order_detail_screen.dart` uses for its
    // duration-input dialog, avoiding the
    // TextEditingController-used-after-disposed crash a dialog-owned
    // controller caused elsewhere in this repo.
    var note = '';
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Төлбөр буцаах'),
        content: TextFormField(
          key: const ValueKey('appointment_refund_note_input'),
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Шалтгаан (заавал)'),
          onChanged: (value) => note = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Болих'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Үргэлжлүүлэх'),
          ),
        ],
      ),
    );
    if (proceed != true || !context.mounted) return;
    final trimmedNote = note.trim();
    if (trimmedNote.isEmpty) {
      messageError('Шалтгаан заавал шаардлагатай');
      return;
    }
    // Refund is destructive — an explicit, separate confirm step precedes
    // the request beyond the note dialog itself.
    final ok = await ConfirmSheet.show(
      context,
      title: 'Төлбөрийг буцаах уу?',
      message: 'Энэ үйлдлийг буцаах боломжгүй.',
      confirmLabel: 'Буцаах',
      isDangerous: true,
      icon: Icons.undo,
    );
    if (!ok || !context.mounted) return;
    final result = await controller.refundPayment(note: trimmedNote);
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        messageComplete('Төлбөр буцаагдлаа');
      case Err(:final error):
        messageError(error.display);
    }
  }

  Future<void> _convertToOrder(BuildContext context) async {
    final controller = context.read<AppointmentDetailController>();
    final result = await controller.convertToOrder();
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        messageComplete('Захиалга үүсгэгдлээ');
      case Err(:final error):
        messageError(error.display);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppointmentDetailController>();
    final appointment = controller.appointment;
    if (appointment == null) {
      return Scaffold(
        backgroundColor: context.opsBackground,
        appBar: AppBar(title: const Text('Цаг захиалга')),
        body: const Center(child: Text('Цаг захиалга олдсонгүй')),
      );
    }

    return Scaffold(
      backgroundColor: context.opsBackground,
      appBar: AppBar(
        title: const Text('Цаг захиалгын дэлгэрэнгүй'),
        actions: [
          IconButton(
            key: const ValueKey('appointment_detail_refresh_button'),
            onPressed: controller.mutating ? null : controller.refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Шинэчлэх',
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 700;
            final content = _DetailContent(
              appointment: appointment,
              controller: controller,
              canEdit: canEdit,
              canViewPayments: canViewPayments,
              canEditPayments: canEditPayments,
              canRefund: canRefund,
              canCreateOrder: canCreateOrder,
              canViewOrders: canViewOrders,
              onConfirm: () => _run(
                context,
                () => context.read<AppointmentDetailController>().confirm(),
              ),
              onReject: () => _run(
                context,
                () => context.read<AppointmentDetailController>().reject(),
              ),
              onArrived: () => _run(
                context,
                () => context.read<AppointmentDetailController>().markArrived(),
              ),
              onNoShow: () => _run(
                context,
                () => context.read<AppointmentDetailController>().markNoShow(),
              ),
              onCancel: () => _cancel(context),
              onReschedule: () => _reschedule(context),
              onCheckPayment: () => _run(
                context,
                () =>
                    context.read<AppointmentDetailController>().checkPayment(),
              ),
              onRetryPayment: () => _run(
                context,
                () =>
                    context.read<AppointmentDetailController>().retryPayment(),
              ),
              onRefund: () => _refund(context),
              onConvertToOrder: () => _convertToOrder(context),
            );
            final padded = Padding(
              padding: const EdgeInsets.all(AppDimens.paddingMD),
              child: content,
            );
            return SingleChildScrollView(
              child: wide
                  ? Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: padded,
                      ),
                    )
                  : padded,
            );
          },
        ),
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.appointment,
    required this.controller,
    required this.canEdit,
    required this.canViewPayments,
    required this.canEditPayments,
    required this.canRefund,
    required this.canCreateOrder,
    required this.canViewOrders,
    required this.onConfirm,
    required this.onReject,
    required this.onArrived,
    required this.onNoShow,
    required this.onCancel,
    required this.onReschedule,
    required this.onCheckPayment,
    required this.onRetryPayment,
    required this.onRefund,
    required this.onConvertToOrder,
  });

  final AppointmentSummary appointment;
  final AppointmentDetailController controller;
  final bool canEdit;
  final bool canViewPayments;
  final bool canEditPayments;
  final bool canRefund;
  final bool canCreateOrder;
  final bool canViewOrders;
  final VoidCallback onConfirm;
  final VoidCallback onReject;
  final VoidCallback onArrived;
  final VoidCallback onNoShow;
  final VoidCallback onCancel;
  final VoidCallback onReschedule;
  final VoidCallback onCheckPayment;
  final VoidCallback onRetryPayment;
  final VoidCallback onRefund;
  final VoidCallback onConvertToOrder;

  @override
  Widget build(BuildContext context) {
    final status = appointment.status;
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    final busy = controller.mutating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (controller.refreshError != null)
          _RefreshWarning(
            message: controller.refreshError!.display,
            onRetry: controller.refresh,
          ),
        if (controller.refreshError != null)
          const SizedBox(height: AppDimens.paddingSM),
        Container(
          padding: const EdgeInsets.all(AppDimens.paddingMD),
          decoration: BoxDecoration(
            color: context.opsCardBg,
            borderRadius: BorderRadius.circular(AppDimens.radiusMD),
            border: Border.all(color: context.opsDivider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      appointment.displayName,
                      style: context.textStyles.h3,
                    ),
                  ),
                  _StatusChip(status: status),
                ],
              ),
              const SizedBox(height: AppDimens.paddingXS),
              Text(appointment.displayPhone, style: context.textStyles.caption),
              const SizedBox(height: AppDimens.paddingSM),
              if (appointment.requestedAt != null)
                _InfoRow(
                  icon: Icons.event_outlined,
                  label: 'Хүсэлт гаргасан цаг',
                  value: dateFmt.format(appointment.requestedAt!),
                ),
              if (appointment.branch?.name != null)
                _InfoRow(
                  icon: Icons.store_outlined,
                  label: 'Салбар',
                  value: appointment.branch!.name!,
                ),
              if (appointment.category?.name != null)
                _InfoRow(
                  icon: Icons.build_outlined,
                  label: 'Ажлын төрөл',
                  value: appointment.category!.name!,
                ),
              if (appointment.displayVehicle?.displayName.isNotEmpty == true)
                _InfoRow(
                  icon: Icons.directions_car_outlined,
                  label: 'Тээврийн хэрэгсэл',
                  value: appointment.displayVehicle!.displayName,
                ),
              if (appointment.note != null && appointment.note!.isNotEmpty)
                _InfoRow(
                  icon: Icons.notes_outlined,
                  label: 'Тэмдэглэл',
                  value: appointment.note!,
                ),
              if (appointment.serviceOrder != null && canViewOrders)
                _LinkedOrderRow(
                  order: appointment.serviceOrder!,
                  onTap: () => context.push(
                    appointmentOrderRoute(appointment.serviceOrder!.id),
                  ),
                ),
              if (controller.arrived == true)
                const _InfoRow(
                  icon: Icons.check_circle_outline,
                  label: 'Ирсэн эсэх',
                  value: 'Ирсэн',
                ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.paddingMD),
        if (canEdit)
          _LifecycleActions(
            status: status,
            arrived: controller.arrived,
            busy: busy,
            onConfirm: onConfirm,
            onReject: onReject,
            onArrived: onArrived,
            onNoShow: onNoShow,
            onCancel: onCancel,
            onReschedule: onReschedule,
          ),
        if (canEdit) const SizedBox(height: AppDimens.paddingMD),
        if (canCreateOrder &&
            appointment.serviceOrder == null &&
            appointment.branch != null &&
            appointment.customer?.id != null &&
            appointment.vehicle?.id != null)
          FilledButton.icon(
            key: const ValueKey('appointment_convert_order_button'),
            onPressed: busy ? null : onConvertToOrder,
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: const Text('Захиалга үүсгэх'),
          ),
        if (canCreateOrder &&
            appointment.serviceOrder == null &&
            appointment.branch != null &&
            appointment.customer?.id != null &&
            appointment.vehicle?.id != null)
          const SizedBox(height: AppDimens.paddingMD),
        if (canViewPayments)
          AppointmentPaymentPanel(
            status: controller.paymentStatus,
            busy: busy,
            detailMessage:
                controller.lastPaymentCheck?.message ??
                (controller.lastPaymentRetry != null
                    ? 'Сүүлд шалгасан үр дүн шинэчлэгдсэн'
                    : null),
            onCheck: onCheckPayment,
            onRetry: canEditPayments ? onRetryPayment : null,
            onRefund: canRefund ? onRefund : null,
          ),
      ],
    );
  }
}

class _LinkedOrderRow extends StatelessWidget {
  const _LinkedOrderRow({required this.order, required this.onTap});

  final AppointmentOrderRef order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final value = order.number != null ? '#${order.number}' : order.id;
    return Padding(
      padding: const EdgeInsets.only(top: AppDimens.paddingSM),
      child: InkWell(
        key: const ValueKey('appointment_linked_order_button'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusSM),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: AppDimens.iconSM,
                color: context.opsAccent,
              ),
              const SizedBox(width: AppDimens.paddingSM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Холбогдох захиалга',
                      style: context.textStyles.caption,
                    ),
                    Text(
                      value,
                      style: context.textStyles.bodyMedium.copyWith(
                        color: context.opsAccent,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new,
                size: AppDimens.iconSM,
                color: context.opsAccent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LifecycleActions extends StatelessWidget {
  const _LifecycleActions({
    required this.status,
    required this.arrived,
    required this.busy,
    required this.onConfirm,
    required this.onReject,
    required this.onArrived,
    required this.onNoShow,
    required this.onCancel,
    required this.onReschedule,
  });

  final AppointmentStatus status;
  final bool? arrived;
  final bool busy;
  final VoidCallback onConfirm;
  final VoidCallback onReject;
  final VoidCallback onArrived;
  final VoidCallback onNoShow;
  final VoidCallback onCancel;
  final VoidCallback onReschedule;

  @override
  Widget build(BuildContext context) {
    // `unknown` never offers any action — by design it carries no
    // `nextStatuses`, and the arrived/reschedule preconditions below both
    // require an exact CONFIRMED match, so `unknown` falls through to none.
    return Wrap(
      spacing: AppDimens.paddingSM,
      runSpacing: AppDimens.paddingSM,
      children: [
        if (AppointmentDetailController.canConfirm(status))
          FilledButton.icon(
            key: const ValueKey('appointment_confirm_button'),
            onPressed: busy ? null : onConfirm,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Баталгаажуулах'),
          ),
        if (AppointmentDetailController.canReject(status))
          OutlinedButton.icon(
            key: const ValueKey('appointment_reject_button'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.opsDanger,
              side: BorderSide(color: context.opsDanger),
            ),
            onPressed: busy ? null : onReject,
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Татгалзах'),
          ),
        if (AppointmentDetailController.canMarkArrived(status, arrived))
          OutlinedButton.icon(
            key: const ValueKey('appointment_arrived_button'),
            onPressed: busy ? null : onArrived,
            icon: const Icon(Icons.login, size: 18),
            label: const Text('Ирсэн'),
          ),
        if (AppointmentDetailController.canMarkNoShow(status))
          OutlinedButton.icon(
            key: const ValueKey('appointment_no_show_button'),
            onPressed: busy ? null : onNoShow,
            icon: const Icon(Icons.person_off_outlined, size: 18),
            label: const Text('Ирээгүй'),
          ),
        if (AppointmentDetailController.canReschedule(status))
          OutlinedButton.icon(
            key: const ValueKey('appointment_reschedule_button'),
            onPressed: busy ? null : onReschedule,
            icon: const Icon(Icons.schedule, size: 18),
            label: const Text('Цаг шилжүүлэх'),
          ),
        if (AppointmentDetailController.canCancel(status))
          OutlinedButton.icon(
            key: const ValueKey('appointment_cancel_button'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.opsDanger,
              side: BorderSide(color: context.opsDanger),
            ),
            onPressed: busy ? null : onCancel,
            icon: const Icon(Icons.event_busy_outlined, size: 18),
            label: const Text('Цуцлах'),
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final color = context.appointmentStatusColor(status);
    return Container(
      key: const ValueKey('appointment_status_chip'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
      ),
      child: Text(
        status.label,
        style: context.textStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppDimens.paddingSM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppDimens.iconSM, color: context.opsTextSecondary),
          const SizedBox(width: AppDimens.paddingSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.textStyles.caption),
                Text(value, style: context.textStyles.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RefreshWarning extends StatelessWidget {
  const _RefreshWarning({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('appointment_detail_refresh_warning'),
      padding: const EdgeInsets.all(AppDimens.paddingMD),
      decoration: BoxDecoration(
        color: context.opsWarning.withValues(alpha: 0.12),
        border: Border.all(color: context.opsWarning.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(AppDimens.radiusMD),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.sync_problem_outlined,
            color: context.opsWarning,
            size: AppDimens.iconMD,
          ),
          const SizedBox(width: AppDimens.paddingSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Шинэ мэдээллийг татаж чадсангүй',
                  style: context.textStyles.bodyMedium,
                ),
                const SizedBox(height: AppDimens.paddingXS),
                Text(
                  '$message. Доорх мэдээлэл хуучирсан байж болзошгүй.',
                  style: context.textStyles.caption,
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('appointment_detail_refresh_retry'),
            onPressed: onRetry,
            tooltip: 'Дахин оролдох',
            icon: const Icon(Icons.refresh),
            color: context.opsWarning,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
