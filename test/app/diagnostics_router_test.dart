import 'package:carcare_service/app/router.dart';
import 'package:carcare_service/app/shell/app_shell.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/services/subscription_service.dart';
import 'package:carcare_service/features/controllers.dart';
import 'package:carcare_service/features/diagnostics/presentation/screens/new_inspection_screen.dart';
import 'package:carcare_service/features/diagnostics/presentation/screens/create_template_screen.dart';
import 'package:carcare_service/features/diagnostics/presentation/screens/report_list_screen.dart';
import 'package:carcare_service/features/diagnostics/presentation/screens/report_detail_screen.dart';
import 'package:carcare_service/features/diagnostics/presentation/screens/template_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

import '../fakes/fake_api_backend.dart';
import '../support/app_harness.dart';
import '../support/hive_test_setup.dart';

void main() {
  setUpAll(openTestHiveBoxes);
  setUp(() {
    FakeApiBackend.instance.reset();
    SubscriptionService.instance.invalidate();
  });

  User signedInUser() => User(
    accessToken: 'test-token',
    refreshToken: 'test-refresh',
    id: 'test-user',
    email: 'test@example.com',
    firstName: 'Test',
    lastName: 'User',
    phone: '',
    isOwner: true,
    tenant: UserTenant('test-tenant', 'Test tenant'),
  );

  Map<String, dynamic> emptyTemplates() => {'templates': <dynamic>[]};
  Map<String, dynamic> emptyReports() => {
    'reports': <dynamic>[],
    'pagination': {
      'page': 1,
      'pageSize': 50,
      'total': 0,
      'totalPages': 1,
      'hasPrev': false,
      'hasNext': false,
    },
  };

  Future<RouterHarness> launch(WidgetTester tester) async {
    Authenticator.user = signedInUser();
    final harness = RouterHarness();
    harness.authController.setAuthState(AuthState.authorized);
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    return harness;
  }

  testWidgets('report and template list routes are deep-linkable', (
    tester,
  ) async {
    FakeApiBackend.instance.onJson(
      'GET',
      'diagnostics/reports',
      emptyReports(),
    );
    FakeApiBackend.instance.onJson(
      'GET',
      'diagnostics/templates',
      emptyTemplates(),
    );
    final harness = await launch(tester);
    addTearDown(() {
      harness.dispose();
      Authenticator.user = null;
    });

    harness.router.go(AppRoutes.diagnosticsReports);
    await tester.pumpAndSettle();
    expect(find.byType(ReportListScreen), findsOneWidget);
    expect(find.text('Оношилгооны тайлан алга.'), findsOneWidget);

    harness.router.go(AppRoutes.diagnosticsTemplates);
    await tester.pumpAndSettle();
    expect(find.byType(TemplateListScreen), findsOneWidget);
    expect(find.text('Оношилгооны загвар алга.'), findsOneWidget);
  });

  testWidgets('standalone report creation literal wins over :id', (
    tester,
  ) async {
    FakeApiBackend.instance.onJson(
      'GET',
      'diagnostics/reports',
      emptyReports(),
    );
    FakeApiBackend.instance.onJson(
      'GET',
      'diagnostics/templates',
      emptyTemplates(),
    );
    final harness = await launch(tester);
    addTearDown(() {
      harness.dispose();
      Authenticator.user = null;
    });
    harness.router.go('${AppRoutes.diagnosticsReports}/new');
    await tester.pumpAndSettle();
    expect(find.byType(NewInspectionScreen), findsOneWidget);
  });

  testWidgets('template detail route fetches and renders selected template', (
    tester,
  ) async {
    FakeApiBackend.instance.onJson('GET', 'diagnostics/templates/template-1', {
      'template': {
        'id': 'template-1',
        'name': 'Үндсэн үзлэг',
        'type': 'INTAKE',
        'schema': {'sections': []},
      },
    });
    final harness = await launch(tester);
    addTearDown(() {
      harness.dispose();
      Authenticator.user = null;
    });
    harness.router.go('${AppRoutes.diagnosticsTemplates}/template-1');
    await tester.pumpAndSettle();
    expect(find.byType(CreateTemplateScreen), findsOneWidget);
    expect(find.text('Загвар засах'), findsOneWidget);
  });

  testWidgets('template create literal route opens the editor', (tester) async {
    final harness = await launch(tester);
    addTearDown(() {
      harness.dispose();
      Authenticator.user = null;
    });
    harness.router.go('${AppRoutes.diagnosticsTemplates}/new');
    await tester.pumpAndSettle();
    expect(find.byType(CreateTemplateScreen), findsOneWidget);
    expect(find.text('Загвар үүсгэх'), findsWidgets);
  });

  testWidgets('report detail dynamic route opens the selected report', (
    tester,
  ) async {
    FakeApiBackend.instance.onJson('GET', 'diagnostics/reports/report-1', {
      'report': {
        'id': 'report-1',
        'templateVersion': 1,
        'template': {
          'id': 'template-1',
          'name': 'Үндсэн үзлэг',
          'type': 'INTAKE',
          'version': 1,
          'isActive': true,
          'isSystemDefault': false,
          'schema': {'sections': []},
        },
        'customer': {'id': 'customer-1', 'phone': '99110000'},
        'vehicle': {
          'id': 'vehicle-1',
          'plate': '1234УБА',
          'make': 'Toyota',
          'model': 'Prius',
        },
        'branch': {'id': 'branch-1', 'name': 'Төв салбар'},
        'data': <String, dynamic>{},
      },
    });
    FakeApiBackend.instance.on(
      'GET',
      'diagnostics/reports/report-1/pdf',
      (options) => Response(
        requestOptions: options,
        statusCode: 200,
        data: <int>[37, 80, 68, 70],
      ),
    );
    final harness = await launch(tester);
    addTearDown(() {
      harness.dispose();
      Authenticator.user = null;
    });
    harness.router.go('${AppRoutes.diagnosticsReports}/report-1');
    await tester.pumpAndSettle();
    expect(find.byType(ReportDetailScreen), findsOneWidget);

    await tester.tap(find.byTooltip('PDF татах'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(
      FakeApiBackend.instance.requests.any(
        (request) =>
            request.method == 'GET' &&
            request.path.contains('diagnostics/reports/report-1/pdf'),
      ),
      isTrue,
    );
  });

  testWidgets('template duplicate action calls the repository route', (
    tester,
  ) async {
    FakeApiBackend.instance.onJson('GET', 'diagnostics/templates', {
      'templates': [
        {'id': 'template-1', 'name': 'Үндсэн үзлэг', 'type': 'INTAKE'},
      ],
    });
    FakeApiBackend.instance.onJson(
      'POST',
      'diagnostics/templates/template-1/duplicate',
      {
        'template': {
          'id': 'template-2',
          'name': 'Үндсэн үзлэг (хуулбар)',
          'type': 'INTAKE',
        },
      },
    );
    final harness = await launch(tester);
    addTearDown(() {
      harness.dispose();
      Authenticator.user = null;
    });
    harness.router.go(AppRoutes.diagnosticsTemplates);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Хуулах'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(
      FakeApiBackend.instance.requests.any(
        (request) =>
            request.method == 'POST' &&
            request.path.contains('diagnostics/templates/template-1/duplicate'),
      ),
      isTrue,
    );
  });

  testWidgets(
    'Catalog and Diagnostics nav rows navigate to their destinations',
    (tester) async {
      FakeApiBackend.instance.onJson(
        'GET',
        'diagnostics/reports',
        emptyReports(),
      );
      FakeApiBackend.instance.onJson(
        'GET',
        'diagnostics/templates',
        emptyTemplates(),
      );
      final harness = await launch(tester);
      addTearDown(() {
        harness.dispose();
        Authenticator.user = null;
      });
      harness.router.go(AppRoutes.more);
      await tester.pumpAndSettle();
      expect(find.byType(MoreScreen), findsOneWidget);

      final templateEntry = find.descendant(
        of: find.byType(MoreScreen),
        matching: find.widgetWithText(ListTile, 'Загвар'),
      );
      tester.widget<ListTile>(templateEntry).onTap!();
      await tester.pumpAndSettle();
      expect(find.byType(TemplateListScreen), findsOneWidget);

      harness.router.go(AppRoutes.more);
      await tester.pumpAndSettle();
      final reportEntry = find
          .descendant(
            of: find.byType(MoreScreen),
            matching: find.widgetWithText(ListTile, 'Тайлан'),
          )
          .first;
      tester.widget<ListTile>(reportEntry).onTap!();
      await tester.pumpAndSettle();
      expect(find.byType(ReportListScreen), findsOneWidget);

      harness.router.go(AppRoutes.more);
      await tester.pumpAndSettle();
      final catalogDiagnostics = find.descendant(
        of: find.byType(MoreScreen),
        matching: find.widgetWithText(ListTile, 'Оношилгоо'),
      );
      tester.widget<ListTile>(catalogDiagnostics).onTap!();
      await tester.pumpAndSettle();
      expect(find.byType(TemplateListScreen), findsOneWidget);
    },
  );
}
