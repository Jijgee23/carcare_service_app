import 'package:flutter/material.dart';

import 'package:carcare_service/core/widgets/dialogs/confirm_sheet.dart';
import 'package:carcare_service/features/orders/domain/order.dart';
import 'package:carcare_service/features/orders/presentation/feature_theme.dart';

/// The user's answer to [promptOrderStatusChange]. [durationMinutes] is only
/// set when moving to [OrderStatus.IN_PROGRESS].
typedef OrderStatusDecision = ({int? durationMinutes});

/// Collects the confirmation/input an order status change needs before it is
/// sent: a work duration when starting, a confirm when completing, and a
/// two-step confirm when cancelling. Returns `null` when the user backs out.
///
/// Shared by the order detail screen and the Today board so both surfaces
/// ask the same questions before the same server transition.
Future<OrderStatusDecision?> promptOrderStatusChange(
  BuildContext context,
  OrderStatus status,
) async {
  if (status == OrderStatus.IN_PROGRESS) {
    var input = '60';
    final minutes = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ажлын үргэлжлэх хугацаа'),
        content: TextFormField(
          key: const ValueKey('order_status_duration_input'),
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
            child: const Text('Үргэлжлүүлэх'),
          ),
        ],
      ),
    );
    if (minutes == null) return null;
    return (durationMinutes: minutes);
  }
  if (status == OrderStatus.COMPLETED) {
    final ok = await ConfirmSheet.show(
      context,
      title: 'Захиалга дуусгах уу?',
      message: 'Дуусгасны дараа захиалганд өөрчлөлт хийх боломжгүй болно.',
      confirmLabel: 'Дуусгах',
      icon: Icons.check_circle_outline_rounded,
      iconColor: context.opsGood,
    );
    return ok ? (durationMinutes: null) : null;
  }
  if (status == OrderStatus.CANCELLED) {
    final ok = await ConfirmSheet.steps(
      context,
      steps: [
        ConfirmStep(
          title: 'Захиалга цуцлах уу?',
          message: 'Цуцалсны дараа захиалганд өөрчлөлт хийх боломжгүй болно.',
          confirmLabel: 'Үргэлжлүүлэх',
          icon: Icons.cancel_outlined,
          iconColor: context.opsWarning,
        ),
        ConfirmStep(
          title: 'Цуцлах уу?',
          message: 'Та итгэлтэй байна уу? Энэ үйлдлийг буцаах боломжгүй.',
          confirmLabel: 'Цуцлах',
          icon: Icons.do_not_disturb_on_outlined,
          isDangerous: true,
        ),
      ],
    );
    return ok ? (durationMinutes: null) : null;
  }
  return (durationMinutes: null);
}
