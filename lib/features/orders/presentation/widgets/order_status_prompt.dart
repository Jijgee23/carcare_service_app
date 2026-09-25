import 'package:flutter/material.dart';

import 'package:carcare_service/core/widgets/dialogs/confirm_sheet.dart';
import 'package:carcare_service/features/orders/domain/order.dart';
import 'package:carcare_service/features/orders/presentation/feature_theme.dart';

/// The user's answer to [promptOrderStatusChange]. [durationMinutes] is only
/// set when moving to [OrderStatus.IN_PROGRESS]: always
/// [defaultStartDurationMinutes], never asked.
typedef OrderStatusDecision = ({int? durationMinutes});

/// Sent with every start. The server only uses it when the order has no
/// estimated duration and no timed service items (otherwise it would reject
/// with `DURATION_REQUIRED`); a real estimate always takes precedence.
const defaultStartDurationMinutes = 30;

/// Collects the confirmation an order status change needs before it is
/// sent: a confirm when starting or completing, and a two-step confirm when
/// cancelling. Returns `null` when the user backs out.
///
/// Shared by the order detail screen and the Today board so both surfaces
/// ask the same questions before the same server transition.
Future<OrderStatusDecision?> promptOrderStatusChange(
  BuildContext context,
  OrderStatus status,
) async {
  if (status == OrderStatus.IN_PROGRESS) {
    final ok = await ConfirmSheet.show(
      context,
      title: 'Ажил эхлүүлэх үү?',
      message: 'Захиалгын ажил эхэлж, хугацаа тоологдож эхэлнэ.',
      confirmLabel: 'Эхлүүлэх',
      icon: Icons.play_arrow_rounded,
      iconColor: context.opsAccent,
    );
    return ok ? (durationMinutes: defaultStartDurationMinutes) : null;
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

