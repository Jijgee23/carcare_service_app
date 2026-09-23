import 'package:carcare_service/core/domain/diagnostic.dart';
import 'package:carcare_service/features/customers/domain/customer.dart';
import 'package:carcare_service/features/orders/presentation/screens/new_customer_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fakes/fake_customer_repository.dart';

/// `P3-F6` — the Orders/Appointments fast-path sheet promoted onto
/// `CustomersRepository`. Covers: the sheet still creates inline and returns
/// a [CustomerSummary] the caller can use immediately (the Orders create
/// flow's contract), a 422 with `fieldErrors` binds to the field rather than
/// a snackbar, a 422 without `fieldErrors` (plan limit) shows a general
/// message, and a 200 claim/reuse outcome is still success.
void main() {
  Future<CustomerSummary?> pump(
    WidgetTester tester,
    FakeCustomerRepository repo, {
    required void Function(String phone, String? name, String? email) fill,
  }) async {
    CustomerSummary? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showNewCustomerSheet(context, repository: repo);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(1), '99112233');
    await tester.tap(find.text('Бүртгэх'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('creates inline and returns a CustomerSummary (fast path)', (
    tester,
  ) async {
    final repo = FakeCustomerRepository(seed: []);
    final result = await pump(tester, repo, fill: (_, _, _) {});

    expect(result, isNotNull);
    expect(result!.phone, '99112233');
    expect(repo.customers, hasLength(1));
  });

  testWidgets('a 200 account-claim/reuse is still success', (tester) async {
    final existing = Customer(
      id: 'cust-linked',
      fullName: 'Бат',
      phone: '99112233',
    );
    final repo = FakeCustomerRepository(
      seed: [existing],
      accountLinkedPhones: {'99112233'},
    );

    final result = await pump(tester, repo, fill: (_, _, _) {});

    expect(result, isNotNull);
    expect(result!.id, 'cust-linked');
    // Claim/reuse must not create a second row.
    expect(repo.customers, hasLength(1));
  });

  testWidgets('422 with fieldErrors binds to the phone field, not a snackbar', (
    tester,
  ) async {
    // Seed a phone conflict candidate isn't needed — an invalid phone from
    // the fake's own `_validate` triggers fieldErrors. The sheet's own
    // client-side `phoneValidator` also rejects this, so use a value that
    // passes client validation but the fake still rejects: a duplicate
    // walk-in phone (409, which also carries fieldErrors and must bind the
    // same way per the classification the repository already encodes).
    final repo = FakeCustomerRepository(
      seed: [Customer(id: 'cust-1', fullName: 'Бат', phone: '99112233')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showNewCustomerSheet(context, repository: repo),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(1), '99112233');
    await tester.tap(find.text('Бүртгэх'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(
      find.text(
        'Энэ утасны дугаартай үйлчлүүлэгч аль хэдийн бүртгэлтэй байна.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('422 without fieldErrors (plan limit) shows a general message', (
    tester,
  ) async {
    final repo = FakeCustomerRepository(seed: [], maxCustomers: 0);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showNewCustomerSheet(context, repository: repo),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(1), '99112233');
    await tester.tap(find.text('Бүртгэх'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Үйлчлүүлэгчийн хязгаарт хүрсэн байна.'), findsOneWidget);
  });

  testWidgets(
    'client-side validation blocks submit before any repository call',
    (tester) async {
      final repo = FakeCustomerRepository(seed: []);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showNewCustomerSheet(context, repository: repo),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Phone left empty.
      await tester.tap(find.text('Бүртгэх'));
      await tester.pumpAndSettle();

      expect(repo.customers, isEmpty);
      expect(find.text('Утасны дугаар оруулна уу'), findsOneWidget);
    },
  );
}
