import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/features/roles/presentation/screens/role_form_screen.dart';

import '../data/fake_permission_catalog_repository.dart';
import '../data/fake_role_repository.dart';

/// Widget coverage for `RoleFormScreen` — P6-F3.
void main() {
  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  Future<void> tapSubmit(WidgetTester tester) async {
    final finder = find.byKey(const ValueKey('role_submit_button'));
    // Repeatedly drag the scroll view up until the submit button is on
    // screen — a single scrollUntilVisible pass is not enough once toggling
    // a checkbox grows the form (an order-scope hint appearing).
    for (var attempt = 0; attempt < 10; attempt++) {
      final box = tester.renderObject(finder) as RenderBox;
      final position = box.localToGlobal(Offset.zero);
      if (position.dy < 550) break;
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
    }
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('picker built from the catalogue', () {
    testWidgets('renders every group and item the fake catalogue returns', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        RoleFormScreen(
          rolesRepository: FakeRoleRepository(),
          catalogRepository: FakePermissionCatalogRepository(),
        ),
      );

      expect(find.text('orders'), findsOneWidget);
      expect(find.text('employees'), findsOneWidget);
      expect(find.text('Бусад'), findsOneWidget); // standalone section
      expect(find.text('Захиалга харах'), findsOneWidget);
      expect(find.text('Ажилтан устгах'), findsOneWidget);
      expect(find.text('Ажлын хувиар удирдах'), findsOneWidget);
    });
  });

  group('group select-all toggle', () {
    testWidgets('toggling the group header checkbox selects every item', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        RoleFormScreen(
          rolesRepository: FakeRoleRepository(),
          catalogRepository: FakePermissionCatalogRepository(),
        ),
      );

      final groupCheckbox = find.byKey(
        const ValueKey('role_group_select_all_employees'),
      );
      await tester.tap(groupCheckbox);
      await tester.pumpAndSettle();

      final viewCheckbox = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('role_permission_employees.view')),
      );
      final editCheckbox = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('role_permission_employees.edit')),
      );
      expect(viewCheckbox.value, isTrue);
      expect(editCheckbox.value, isTrue);
    });
  });

  group('order-scope hint (mirrors validateOrderScopes)', () {
    testWidgets('selecting orders.edit without orders.view shows the hint', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        RoleFormScreen(
          rolesRepository: FakeRoleRepository(),
          catalogRepository: FakePermissionCatalogRepository(),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('role_permission_orders.edit')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Салбарын засах эрхэд Салбарын харах эрх шаардлагатай.'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('role_permission_orders.view')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Салбарын засах эрхэд Салбарын харах эрх шаардлагатай.'),
        findsNothing,
      );
    });
  });

  group('validation', () {
    testWidgets('submitting with no name and no permissions shows both hints', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        RoleFormScreen(
          rolesRepository: FakeRoleRepository(),
          catalogRepository: FakePermissionCatalogRepository(),
        ),
      );

      await tapSubmit(tester);

      expect(find.text('Нэрээ оруулна уу.'), findsOneWidget);
      expect(find.text('Дор хаяж нэг эрх сонгоно уу.'), findsOneWidget);
    });
  });

  group('server error surfacing', () {
    testWidgets('DUPLICATE from the repository is shown under the name field', (
      tester,
    ) async {
      final repo = FakeRoleRepository(
        seed: [FakeRoleRepository.seedRole(id: 'r1', name: 'Механик')],
      );
      await pumpScreen(
        tester,
        RoleFormScreen(
          rolesRepository: repo,
          catalogRepository: FakePermissionCatalogRepository(),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('role_name_field')),
        'Механик',
      );
      await tester.tap(
        find.byKey(const ValueKey('role_permission_orders.view')),
      );
      await tapSubmit(tester);

      expect(find.text('Давхардсан нэр.'), findsOneWidget);
    });
  });
}
