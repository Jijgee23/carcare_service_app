import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/domain/subscription.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/customers/domain/customer.dart';
import 'package:carcare_service/features/customers/presentation/screens/customer_broadcast_screen.dart';

import '../../fakes/fake_customer_repository.dart';

/// A fake that holds [sendBroadcast] open until [release] is called, so the
/// widget test can observe the UI mid-flight (send button disabled) rather
/// than only asserting on the end state. Local subclass per the P3-F7
/// constraint against editing the shared fake.
class _SlowSendRepository extends FakeCustomerRepository {
  _SlowSendRepository({super.seed, super.accountLinkedPhones});

  int sendCalls = 0;
  Completer<void>? _gate;

  @override
  Future<Result<CustomerBroadcastResult>> sendBroadcast({
    required String title,
    required String body,
  }) async {
    sendCalls++;
    final gate = _gate ??= Completer<void>();
    await gate.future;
    return super.sendBroadcast(title: title, body: body);
  }

  void release() {
    _gate?.complete();
  }
}

/// Widget coverage for the customer broadcast surface — P3-F7.
///
/// Covers: permission gating, subscription gating, the recipient count
/// (including the zero case rendered as a dead end — no enabled send
/// button), the daily-limit rejection message, the required confirmation
/// step, and that a second tap while a send is in flight cannot fire twice.
User _user(List<String> permissions, {bool isOwner = false}) => User(
  accessToken: 'token',
  refreshToken: 'refresh',
  id: 'user',
  email: 'user@example.test',
  firstName: 'Test',
  lastName: 'User',
  phone: '99001122',
  isOwner: isOwner,
  role: UserRole('role', 'Role', permissions),
  tenant: UserTenant('tenant', 'Tenant'),
);

const _activeSub = SubscriptionStatus(
  plan: 'pro',
  status: 'active',
  locked: false,
  isTrial: false,
  daysLeft: 20,
  expiresAt: null,
  expiringSoon: false,
  warnDays: null,
  hasPendingPayment: false,
);

const _lockedSub = SubscriptionStatus(
  plan: 'pro',
  status: 'expired',
  locked: true,
  isTrial: false,
  daysLeft: 0,
  expiresAt: null,
  expiringSoon: false,
  warnDays: null,
  hasPendingPayment: false,
);

Future<void> _pump(
  WidgetTester tester, {
  required FakeCustomerRepository repo,
  required User user,
  SubscriptionStatus? subscriptionStatus = _activeSub,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: CustomerBroadcastScreen(
        repo: repo,
        user: user,
        subscriptionStatus: subscriptionStatus,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  testWidgets('missing customers.notify permission shows the gate message, '
      'not the form', (tester) async {
    final repo = FakeCustomerRepository(
      seed: [Customer(id: 'c1', fullName: 'Бат', phone: '99001111')],
      accountLinkedPhones: {'99001111'},
    );
    await _pump(tester, repo: repo, user: _user(const ['customers.view']));

    expect(
      find.text('Танд зар мэдээ илгээх эрх байхгүй байна.'),
      findsOneWidget,
    );
    expect(find.text('Илгээх'), findsNothing);
  });

  testWidgets('a locked subscription blocks the form even with permission', (
    tester,
  ) async {
    final repo = FakeCustomerRepository(
      seed: [Customer(id: 'c1', fullName: 'Бат', phone: '99001111')],
      accountLinkedPhones: {'99001111'},
    );
    await _pump(
      tester,
      repo: repo,
      user: _user(const ['customers.notify']),
      subscriptionStatus: _lockedSub,
    );

    expect(find.textContaining('Идэвхтэй захиалга'), findsOneWidget);
    expect(find.text('Илгээх'), findsNothing);
  });

  testWidgets('permission + active subscription renders the recipient '
      'count and the walk-in caveat', (tester) async {
    final repo = FakeCustomerRepository(
      seed: [
        Customer(id: 'c1', fullName: 'Бат', phone: '99001111'),
        Customer(id: 'c2', fullName: 'Дорж', phone: '99002222'),
      ],
      accountLinkedPhones: {'99001111'},
    );
    await _pump(tester, repo: repo, user: _user(const ['customers.notify']));

    expect(find.text('Хүлээн авагч: 1'), findsOneWidget);
    expect(find.textContaining('биечлэн үйлчлүүлдэг'), findsOneWidget);
    expect(find.text('Илгээх'), findsOneWidget);
  });

  testWidgets('zero recipients renders as a dead end: no enabled send', (
    tester,
  ) async {
    final repo = FakeCustomerRepository(
      seed: [Customer(id: 'c1', fullName: 'Бат', phone: '99001111')],
      accountLinkedPhones: const {},
    );
    await _pump(tester, repo: repo, user: _user(const ['customers.notify']));

    expect(find.text('Хүлээн авагч: 0'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Илгээх'),
    );
    expect(button.onPressed, isNull);
    expect(
      find.textContaining('Хүлээн авагч байхгүй тул илгээх боломжгүй'),
      findsOneWidget,
    );
  });

  testWidgets('sending requires confirmation before it reaches the repo', (
    tester,
  ) async {
    final repo = FakeCustomerRepository(
      seed: [Customer(id: 'c1', fullName: 'Бат', phone: '99001111')],
      accountLinkedPhones: {'99001111'},
    );
    await _pump(tester, repo: repo, user: _user(const ['customers.notify']));

    await tester.enterText(find.byType(TextField).at(0), 'Гарчиг');
    await tester.enterText(find.byType(TextField).at(1), 'Агуулга');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Илгээх'));
    await tester.pumpAndSettle();

    // Confirmation sheet is up; the send has not happened yet.
    expect(find.text('Зар илгээх үү?'), findsOneWidget);
    expect(find.textContaining('1 үйлчлүүлэгчид'), findsOneWidget);

    await tester.tap(find.text('Болих'));
    await tester.pumpAndSettle();
    expect(find.text('Илгээх'), findsOneWidget);
  });

  testWidgets('daily-limit rejection is surfaced as a clear message', (
    tester,
  ) async {
    final repo = FakeCustomerRepository(
      seed: [Customer(id: 'c1', fullName: 'Бат', phone: '99001111')],
      accountLinkedPhones: {'99001111'},
      dailyBroadcastLimit: 0,
    );
    await _pump(tester, repo: repo, user: _user(const ['customers.notify']));

    await tester.enterText(find.byType(TextField).at(0), 'Гарчиг');
    await tester.enterText(find.byType(TextField).at(1), 'Агуулга');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Илгээх'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Илгээх').last);
    await tester.pumpAndSettle();

    expect(
      find.text('Өдрийн зар илгээх хязгаарт хүрсэн байна.'),
      findsOneWidget,
    );
    // The failed send still fired a toast (`messageError`), which arms a
    // real 3-second timer regardless of whether an overlay is present to
    // show it. Flush it so the test doesn't end with a timer pending.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'the send button is disabled while a send is in flight, so a second '
    'tap cannot fire a second request',
    (tester) async {
      final repo = _SlowSendRepository(
        seed: [Customer(id: 'c1', fullName: 'Бат', phone: '99001111')],
        accountLinkedPhones: {'99001111'},
      );
      await _pump(tester, repo: repo, user: _user(const ['customers.notify']));

      await tester.enterText(find.byType(TextField).at(0), 'Гарчиг');
      await tester.enterText(find.byType(TextField).at(1), 'Агуулга');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Илгээх'));
      await tester.pumpAndSettle();
      // Confirm the send — this starts the (held-open) request.
      await tester.tap(find.text('Илгээх').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      // While in flight: the main send button is disabled (shows a
      // spinner, no onPressed), so nothing in the UI can dispatch a
      // second request.
      final button = tester.widget<ElevatedButton>(
        find.byKey(const Key('broadcast_send_button')),
      );
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      repo.release();
      await tester.pumpAndSettle();
      expect(repo.sendCalls, 1);
      // The successful send fires `messageComplete`, which arms the same
      // kind of real timer as above — flush it before the test ends.
      await tester.pump(const Duration(seconds: 3));
    },
  );
}
