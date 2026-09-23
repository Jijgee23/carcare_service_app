import 'package:carcare_service/app/router.dart';
import 'package:carcare_service/core/keys/keys.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/features/appointments/presentation/controllers/appointment_controller.dart';
import 'package:carcare_service/features/appointments/presentation/screens/appointment_screen.dart';
import 'package:carcare_service/features/diagnostics/presentation/screens/report_detail_screen.dart';
import 'package:carcare_service/features/notifications/presentation/screens/notification_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Routes a tapped push notification to the relevant screen.
///
/// Data-message payloads vary, so candidate id keys are checked defensively
/// (both camelCase and snake_case). Anything unrecognized — or a tap while
/// signed out — falls back to the notification inbox, which is always safe.
/// Each destination self-loads its data by id. Order notifications use the
/// typed GoRouter route so the production order list/detail provider tree is
/// used, including on a cold start.
class NotificationRouter {
  NotificationRouter._();

  static void route(Map<String, dynamic> data) {
    final router = GlobalKeys.router;
    if (router != null) {
      _route(data);
      return;
    }
    // Defer to the next frame so the app can finish creating its router on a
    // cold start before resolving the notification destination.
    WidgetsBinding.instance.addPostFrameCallback((_) => _route(data));
  }

  static void _route(Map<String, dynamic> data) {
    // Never deep-link into an authenticated screen while signed out.
    if (Authenticator.user == null) return;

    final orderId = _pick(data, const ['orderId', 'order_id', 'serviceOrderId']);
    final reportId = _pick(data, const ['reportId', 'report_id', 'diagnosticReportId']);
    final appointmentId = _pick(data, const ['appointmentId', 'appointment_id']);

    if (orderId != null) {
      final path = '${AppRoutes.orders}/${Uri.encodeComponent(orderId)}';
      // A notification is an external entry point, so replace the current
      // shell location rather than adding a child to whatever redirect was
      // still settling on the initial shell branch. `go` also asks the
      // StatefulShellRoute to activate the Orders branch deterministically.
      GlobalKeys.router?.go(path);
      return;
    }

    final nav = GlobalKeys.navigator.currentState;
    if (nav == null) return;

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
