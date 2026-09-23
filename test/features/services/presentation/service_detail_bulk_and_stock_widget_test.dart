import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/services/domain/service.dart';
import 'package:carcare_service/features/services/presentation/controllers/service_detail_controller.dart';
import 'package:carcare_service/features/services/presentation/screens/bulk_category_screen.dart';
import 'package:carcare_service/features/services/presentation/screens/stock_adjust_sheet.dart';

import '../data/fake_service_repository.dart';

/// Coverage for the two brand-new P4-F3 surfaces that don't fit the
/// `service_detail_*`/`create_service_*` glob but were built in this slice:
/// [StockAdjustSheet] and [BulkCategoryScreen]. Kept as a small, separate
/// file rather than crammed into either glob's file so it's easy to find.
User _user(List<String> permissions) => User(
  accessToken: 'token',
  refreshToken: 'refresh',
  id: 'user',
  email: 'user@example.test',
  firstName: 'Test',
  lastName: 'User',
  phone: '99001122',
  isOwner: false,
  role: UserRole('role', 'Role', permissions),
  tenant: UserTenant('tenant', 'Tenant'),
);

void main() {
  group('StockAdjustSheet', () {
    testWidgets('GOODS-only guard: show() is a no-op for a non-GOODS service', (
      tester,
    ) async {
      final repo = FakeServiceRepository(
        seed: [
          FakeServiceRepository.seedService(
            id: 'svc-1',
            type: ServiceKind.labor,
          ),
        ],
      );
      final ctrl = ServiceDetailController(serviceId: 'svc-1', repo: repo);
      await ctrl.load();
      final service = ctrl.service!;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => StockAdjustSheet.show(
                context,
                service: service,
                controller: ctrl,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Үлдэгдэл тохируулах'), findsNothing);
    });

    testWidgets('a negative-balance rejection binds to the amount field', (
      tester,
    ) async {
      final repo = FakeServiceRepository(
        seed: [
          FakeServiceRepository.seedService(
            id: 'svc-1',
            type: ServiceKind.goods,
            stock: '3',
          ),
        ],
      );
      final ctrl = ServiceDetailController(serviceId: 'svc-1', repo: repo);
      await ctrl.load();
      final service = ctrl.service!;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => StockAdjustSheet.show(
                context,
                service: service,
                controller: ctrl,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('stock_direction_out')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('stock_amount_field')),
        '10',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('stock_adjust_submit')));
      await tester.pumpAndSettle();

      expect(find.textContaining('сөрөг болж байна'), findsOneWidget);
    });
  });

  group('BulkCategoryScreen', () {
    testWidgets('gated on services.edit at the surface level', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BulkCategoryScreen(
            repo: FakeServiceRepository(),
            user: _user(const ['services.view']),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Энэ үйлдэлд эрх байхгүй байна'), findsOneWidget);
    });

    testWidgets(
      'renders per-item bulk-category results, including partial failure',
      (tester) async {
        final repo = _BulkResultRepository();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: BulkCategoryScreen(
              repo: repo,
              user: _user(const ['services.edit']),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));

        // Select the one loaded service, then apply a category.
        await tester.tap(find.text('BRK-001 · Тормозны наклад'));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('bulk_category_apply')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Тормозны систем'));
        await tester.pumpAndSettle();

        expect(find.textContaining('1 амжилттай, 1 амжилтгүй'), findsOneWidget);
        expect(find.textContaining('svc-9: Олдсонгүй'), findsOneWidget);
      },
    );
  });
}

/// Returns a fixed, deliberately partial [BulkCategoryResult] regardless of
/// input, so the widget test can assert the per-item rendering without
/// depending on `FakeServiceRepository`'s own matching rules.
class _BulkResultRepository extends FakeServiceRepository {
  @override
  Future<Result<BulkCategoryResult>> bulkChangeCategory({
    required List<String> serviceIds,
    required String categoryId,
  }) async => const Ok(
    BulkCategoryResult(succeeded: 1, failed: 1, errors: ['svc-9: Олдсонгүй']),
  );
}
