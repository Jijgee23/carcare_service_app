import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/features/appointments/domain/appointment.dart';
import 'package:carcare_service/features/appointments/presentation/screens/appointment_detail_screen.dart';
import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_appointment_repository.dart';
import '../../fakes/fake_order_repository.dart';

User _owner() => User(
  accessToken: 't',
  refreshToken: 'r',
  id: 'u1',
  email: 'u@example.com',
  firstName: 'U',
  lastName: 'U',
  phone: '',
  isOwner: true,
  role: UserRole('r1', 'Owner', const []),
  tenant: UserTenant('t1', 'Tenant'),
);

AppointmentSummary _appt({
  AppointmentVehicleRef? vehicle,
  DateTime? arrivedAt,
}) => AppointmentSummary(
  id: 'a1',
  status: AppointmentStatus.CONFIRMED,
  requestedAt: DateTime(2026, 9, 25, 12, 30),
  branch: const AppointmentBranchRef(id: 'b1', name: 'Үндсэн салбар'),
  customer: const AppointmentCustomerRef(
    id: 'c1',
    fullName: '80779100',
    phone: '80779100',
  ),
  vehicle: vehicle,
  arrivedAt: arrivedAt,
);

Future<void> _pump(WidgetTester tester, AppointmentSummary appt) async {
  await tester.binding.setSurfaceSize(const Size(1024, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: AppointmentDetailScreen(
        initial: appt,
        repo: FakeAppointmentRepository(seed: [appt]),
        ordersRepository: FakeOrderRepository(),
        user: _owner(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'a confirmed appointment with a customer but no vehicle offers create order',
    (tester) async {
      await _pump(tester, _appt());
      expect(
        find.byKey(const ValueKey('appointment_convert_order_button')),
        findsOneWidget,
      );
    },
  );

  testWidgets('an appointment with no customer hides create order', (
    tester,
  ) async {
    await _pump(
      tester,
      AppointmentSummary(
        id: 'a2',
        status: AppointmentStatus.PENDING,
        requestedAt: DateTime(2026, 9, 25, 12, 30),
        branch: const AppointmentBranchRef(id: 'b1'),
      ),
    );
    expect(
      find.byKey(const ValueKey('appointment_convert_order_button')),
      findsNothing,
    );
  });

  testWidgets(
    'an arrived appointment hides Ирсэн/Ирээгүй and shows the arrived row',
    (tester) async {
      await _pump(tester, _appt(arrivedAt: DateTime(2026, 9, 25, 12, 20)));
      expect(
        find.byKey(const ValueKey('appointment_arrived_button')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('appointment_no_show_button')),
        findsNothing,
      );
      expect(find.text('Ирсэн эсэх'), findsOneWidget);
    },
  );

  testWidgets('a not-yet-arrived confirmed appointment offers Ирсэн', (
    tester,
  ) async {
    await _pump(tester, _appt());
    expect(
      find.byKey(const ValueKey('appointment_arrived_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('appointment_no_show_button')),
      findsOneWidget,
    );
  });
}
