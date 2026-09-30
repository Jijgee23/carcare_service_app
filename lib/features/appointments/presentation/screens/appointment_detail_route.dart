import 'package:carservice_business/app/theme/app_theme.dart';
import 'package:carservice_business/core/utils/result.dart';
import 'package:carservice_business/core/widgets/common/common_widgets.dart';
import 'package:carservice_business/features/appointments/data/appointment_repository.dart';
import 'package:carservice_business/features/appointments/domain/appointment.dart';
import 'package:carservice_business/features/appointments/domain/appointments_repository.dart';
import 'package:carservice_business/features/appointments/presentation/screens/appointment_detail_screen.dart';
import 'package:carservice_business/features/orders/presentation/feature_theme.dart';
import 'package:flutter/material.dart';

/// `/appointments/:id` — opens [AppointmentDetailScreen] from just an id
/// (notification taps, cold-start deep links). The detail screen needs a
/// loaded [AppointmentSummary], so this fetches `GET /appointments/[id]`
/// first and shows the server's error verbatim if it fails (e.g. 404 when
/// the appointment is outside the working branch).
class AppointmentDetailRoute extends StatefulWidget {
  const AppointmentDetailRoute({
    super.key,
    required this.appointmentId,
    this.repo,
  });

  final String appointmentId;
  final AppointmentsRepository? repo;

  @override
  State<AppointmentDetailRoute> createState() => _AppointmentDetailRouteState();
}

class _AppointmentDetailRouteState extends State<AppointmentDetailRoute> {
  late final AppointmentsRepository _repo =
      widget.repo ?? RemoteAppointmentsRepository();
  Result<AppointmentSummary>? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_result != null) setState(() => _result = null);
    final result = await _repo.getAppointment(widget.appointmentId);
    if (mounted) setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_result) {
      Ok(:final value) => AppointmentDetailScreen(initial: value, repo: _repo),
      Err(:final error) => Scaffold(
        backgroundColor: context.opsBackground,
        appBar: AppBar(title: const Text('Цаг захиалга')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error.display, textAlign: TextAlign.center),
              const SizedBox(height: AppDimens.paddingMD),
              OutlinedButton(
                onPressed: _load,
                child: const Text('Дахин оролдох'),
              ),
            ],
          ),
        ),
      ),
      null => Scaffold(
        backgroundColor: context.opsBackground,
        appBar: AppBar(title: const Text('Цаг захиалга')),
        body: const AppLoading(),
      ),
    };
  }
}
