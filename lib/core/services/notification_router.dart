import 'package:carcare_service/core/keys/keys.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/features/presentation/controllers/appointment_controller.dart';
import 'package:carcare_service/features/presentation/controllers/order_controller.dart';
import 'package:carcare_service/features/presentation/pages/appointments/appointment_screen.dart';
import 'package:carcare_service/features/presentation/pages/inspection/report_detail_screen.dart';
import 'package:carcare_service/features/presentation/pages/notifications/notification_screen.dart';
import 'package:carcare_service/features/presentation/pages/orders/order_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Routes a tapped push notification to the relevant screen.
///
/// Data-message payloads vary, so candidate id keys are checked defensively
/// (both camelCase and snake_case). Anything unrecognized — or a tap while
/// signed out — falls back to the notification inbox, which is always safe.
/// Each destination self-loads its data by id and is given a fresh controller,
/// so deep-links work from a cold start too.
class NotificationRouter {
  NotificationRouter._();

  static void route(Map<String, dynamic> data) {
    // Defer to the next frame so the root navigator is mounted (cold start).
    WidgetsBinding.instance.addPostFrameCallback((_) => _route(data));
  }

  static void _route(Map<String, dynamic> data) {
    final nav = GlobalKeys.navigator.currentState;
    if (nav == null) return;

    // Never deep-link into an authenticated screen while signed out.
    if (Authenticator.user == null) return;

    final orderId = _pick(data, const ['orderId', 'order_id', 'serviceOrderId']);
    final reportId = _pick(data, const ['reportId', 'report_id', 'diagnosticReportId']);
    final appointmentId = _pick(data, const ['appointmentId', 'appointment_id']);

    if (orderId != null) {
      nav.push(MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => OrderController(),
          child: OrderDetailScreen(orderId: orderId),
        ),
      ));
      return;
    }

    if (reportId != null) {
      nav.push(MaterialPageRoute(builder: (_) => ReportDetailScreen(reportId: reportId)));
      return;
    }

    if (appointmentId != null) {
      // No standalone appointment-detail screen exists; open the day view.
      nav.push(MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => AppointmentController(),
          child: const AppointmentScreen(),
        ),
      ));
      return;
    }

    nav.push(MaterialPageRoute(builder: (_) => const NotificationScreen()));
  }

  static String? _pick(Map<String, dynamic> data, List<String> keys) {
    for (final k in keys) {
      final v = data[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return null;
  }
}
