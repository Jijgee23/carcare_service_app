import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/features/services/domain/service.dart';
import 'package:carcare_service/features/services/presentation/screens/service_detail_screen.dart';

import '../data/fake_service_repository.dart';

/// Widget coverage for the rebuilt `ServiceDetailScreen` — P4-F3.
///
/// Covers: fetch-by-id cold start, the surface-level permission gate
/// (D-163 — the legacy screen this replaces had none at all), edit/delete
/// icon gating, the archive-vs-hard-delete confirm wording, and the
/// `GOODS`-only stock FAB.
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

Future<void> _pump(
  WidgetTester tester, {
  required FakeServiceRepository repo,
  required User user,
  String serviceId = 'svc-1',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: ServiceDetailScreen(serviceId: serviceId, repo: repo, user: user),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  testWidgets(
    'without services.view the screen never fetches, shows a denial',
    (tester) async {
      final repo = FakeServiceRepository(
        seed: [
          FakeServiceRepository.seedService(id: 'svc-1', name: 'Тос солих'),
        ],
      );
      await _pump(tester, repo: repo, user: _user(const []));

      expect(find.text('Тос солих'), findsNothing);
      expect(
        find.text('Энэ мэдээллийг үзэх эрх байхгүй байна'),
        findsOneWidget,
      );
    },
  );

  testWidgets('cold start fetches by id and renders detail', (tester) async {
    final repo = FakeServiceRepository(
      seed: [
        FakeServiceRepository.seedService(
          id: 'svc-1',
          name: 'Тос солих',
          price: '15000.00',
        ),
      ],
    );
    await _pump(tester, repo: repo, user: _user(const ['services.view']));

    expect(find.textContaining('Тос солих'), findsWidgets);
  });

  testWidgets('edit/delete icons are hidden without permission', (
    tester,
  ) async {
    final repo = FakeServiceRepository(
      seed: [FakeServiceRepository.seedService(id: 'svc-1')],
    );
    await _pump(tester, repo: repo, user: _user(const ['services.view']));

    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('edit/delete icons show and are enabled with permission', (
    tester,
  ) async {
    final repo = FakeServiceRepository(
      seed: [FakeServiceRepository.seedService(id: 'svc-1')],
    );
    await _pump(
      tester,
      repo: repo,
      user: _user(const ['services.view', 'services.edit', 'services.delete']),
    );

    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    final editButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.edit_outlined),
        matching: find.byType(IconButton),
      ),
    );
    expect(editButton.onPressed, isNotNull);
  });

  testWidgets(
    'delete confirm warns "archive" when the service has order-item history',
    (tester) async {
      final repo = FakeServiceRepository(
        seed: [
          FakeServiceRepository.seedService(id: 'svc-1', orderItemCount: 4),
        ],
      );
      await _pump(
        tester,
        repo: repo,
        user: _user(const ['services.view', 'services.delete']),
      );

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.textContaining('архивлана'), findsOneWidget);
    },
  );

  testWidgets('delete confirm warns permanent removal when unreferenced', (
    tester,
  ) async {
    final repo = FakeServiceRepository(
      seed: [FakeServiceRepository.seedService(id: 'svc-1', orderItemCount: 0)],
    );
    await _pump(
      tester,
      repo: repo,
      user: _user(const ['services.view', 'services.delete']),
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.textContaining('бүрмөсөн устгахдаа'), findsOneWidget);
  });

  testWidgets('stock FAB shows only for GOODS with services.edit', (
    tester,
  ) async {
    final repo = FakeServiceRepository(
      seed: [
        FakeServiceRepository.seedService(id: 'svc-1', type: ServiceKind.goods),
      ],
    );
    await _pump(
      tester,
      repo: repo,
      user: _user(const ['services.view', 'services.edit']),
    );

    expect(find.byKey(const ValueKey('service_stock_fab')), findsOneWidget);
  });

  testWidgets('stock FAB is absent for a non-GOODS service', (tester) async {
    final repo = FakeServiceRepository(
      seed: [
        FakeServiceRepository.seedService(id: 'svc-1', type: ServiceKind.labor),
      ],
    );
    await _pump(
      tester,
      repo: repo,
      user: _user(const ['services.view', 'services.edit']),
    );

    expect(find.byKey(const ValueKey('service_stock_fab')), findsNothing);
  });

  testWidgets('stock FAB is absent without services.edit even for GOODS', (
    tester,
  ) async {
    final repo = FakeServiceRepository(
      seed: [
        FakeServiceRepository.seedService(id: 'svc-1', type: ServiceKind.goods),
      ],
    );
    await _pump(tester, repo: repo, user: _user(const ['services.view']));

    expect(find.byKey(const ValueKey('service_stock_fab')), findsNothing);
  });
}
