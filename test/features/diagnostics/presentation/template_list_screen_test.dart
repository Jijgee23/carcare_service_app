import 'package:carservice_business/app/theme/app_theme.dart';
import 'package:carservice_business/core/domain/user.dart';
import 'package:carservice_business/core/errors/app_error.dart';
import 'package:carservice_business/core/utils/result.dart';
import 'package:carservice_business/features/diagnostics/domain/diagnostic.dart';
import 'package:carservice_business/features/diagnostics/domain/diagnostics_repository.dart';
import 'package:carservice_business/features/diagnostics/presentation/screens/template_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Repo implements DiagnosticTemplateRepository {
  _Repo(this.templates);

  List<DiagnosticTemplateSummary> templates;
  final loads = <bool>[];
  final deleted = <String>[];
  final duplicated = <String>[];
  TemplateDeleteOutcome outcome = TemplateDeleteOutcome.deleted;

  @override
  Future<Result<List<DiagnosticTemplateSummary>>> getTemplates({
    bool includeInactive = false,
  }) async {
    loads.add(includeInactive);
    return Ok(templates);
  }

  @override
  Future<Result<TemplateDeleteOutcome>> deleteTemplate(String id) async {
    deleted.add(id);
    return Ok(outcome);
  }

  @override
  Future<Result<DiagnosticTemplateSummary>> duplicateTemplate(String id) async {
    duplicated.add(id);
    return Ok(templates.firstWhere((t) => t.id == id));
  }

  @override
  Future<Result<DiagnosticTemplateDetail>> getTemplate(String id) async =>
      const Err(AppError(ErrorKind.notFound, 'unused'));
  @override
  Future<Result<DiagnosticTemplateSummary>> createTemplate(
    Map<String, dynamic> body,
  ) async => const Err(AppError(ErrorKind.unknown, 'unused'));
  @override
  Future<Result<DiagnosticTemplateSummary>> updateTemplate(
    String id,
    Map<String, dynamic> body,
  ) async => const Err(AppError(ErrorKind.unknown, 'unused'));
}

DiagnosticTemplateSummary _t(
  String id,
  String name, {
  DiagnosticType type = DiagnosticType.INTAKE,
  bool isActive = true,
  bool isSystemDefault = false,
  double? price,
  int? durationMin,
  int version = 1,
  int? reportCount,
  String? description,
}) => DiagnosticTemplateSummary(
  id: id,
  name: name,
  description: description,
  type: type,
  version: version,
  isActive: isActive,
  isSystemDefault: isSystemDefault,
  price: price,
  durationMin: durationMin,
  reportCount: reportCount,
);

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

const _all = [
  'diagnostics.view',
  'diagnostics.create',
  'diagnostics.edit',
  'diagnostics.delete',
];

Future<_Repo> _pump(
  WidgetTester tester,
  List<DiagnosticTemplateSummary> templates, {
  List<String> permissions = _all,
}) async {
  final repo = _Repo(templates);
  await tester.pumpWidget(
    GetMaterialApp(
      theme: AppTheme.light,
      home: TemplateListScreen(repo: repo, user: _user(permissions)),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

/// Opens the ⋯ menu on the card for [id].
Future<void> _openMenu(WidgetTester tester, String id) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(ValueKey('diagnostic_template_$id')),
      matching: find.byTooltip('Үйлдэл'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists every template, active first, with its type, price, '
      'duration, version and status', (tester) async {
    final repo = await _pump(tester, [
      _t('old', 'Хуучин үзлэг', type: DiagnosticType.ROUTINE, isActive: false),
      _t(
        'intake',
        'Хүлээж авах үзлэг',
        price: 25000,
        durationMin: 30,
        version: 3,
        description: 'Машин хүлээж авах үед',
      ),
    ]);

    expect(repo.loads, [true], reason: 'inactive templates are listed too');
    expect(find.text('Оношилгоо'), findsOneWidget);
    // The type chip on the card (the filter row has one too).
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('diagnostic_template_intake')),
        matching: find.text('Хүлээж авах'),
      ),
      findsOneWidget,
    );
    expect(find.text('25,000₮'), findsOneWidget);
    expect(find.text('30мин'), findsOneWidget);
    expect(find.text('v3'), findsOneWidget);
    expect(find.text('Машин хүлээж авах үед'), findsOneWidget);
    expect(find.text('Идэвхтэй'), findsOneWidget);
    expect(find.text('Идэвхгүй'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Хүлээж авах үзлэг')).dy,
      lessThan(tester.getTopLeft(find.text('Хуучин үзлэг')).dy),
    );
    expect(
      find.byKey(const ValueKey('diagnostic_templates_add')),
      findsOneWidget,
    );
  });

  testWidgets('the type chips and the search narrow the list', (tester) async {
    await _pump(tester, [
      _t('a', 'Хүлээж авах үзлэг'),
      _t('b', 'Тогтмол шалгалт', type: DiagnosticType.ROUTINE),
    ]);

    await tester.tap(
      find.byKey(const ValueKey('diagnostic_templates_type_ROUTINE')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Хүлээж авах үзлэг'), findsNothing);
    expect(find.text('Тогтмол шалгалт'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('diagnostic_templates_type_null')),
    );
    await tester.enterText(find.byType(TextField), 'хүлээж');
    await tester.pumpAndSettle();
    expect(find.text('Хүлээж авах үзлэг'), findsOneWidget);
    expect(find.text('Тогтмол шалгалт'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Хайлтад тохирох оношилгоо олдсонгүй'), findsOneWidget);
  });

  testWidgets('a template with reports is archived rather than deleted', (
    tester,
  ) async {
    final repo = await _pump(tester, [
      _t('a', 'Хүлээж авах үзлэг', reportCount: 4),
    ]);
    repo.outcome = TemplateDeleteOutcome.archived;

    await _openMenu(tester, 'a');
    await tester.tap(find.text('Устгах'));
    await tester.pumpAndSettle();
    expect(
      find.text('"Хүлээж авах үзлэг" загварыг архивлах уу?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Архивлах'));
    await tester.pumpAndSettle();

    expect(repo.deleted, ['a']);
    expect(repo.loads, [true, true], reason: 'reloaded afterwards');
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('duplicating reloads the list', (tester) async {
    final repo = await _pump(tester, [_t('a', 'Хүлээж авах үзлэг')]);

    await _openMenu(tester, 'a');
    await tester.tap(find.text('Хуулах'));
    await tester.pumpAndSettle();

    expect(repo.duplicated, ['a']);
    expect(repo.loads, [true, true]);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('a system template can be viewed and copied, never deleted', (
    tester,
  ) async {
    await _pump(tester, [
      _t('sys', 'Ерөнхий үзлэг (хүлээж авах)', isSystemDefault: true),
    ]);

    expect(find.text('Системийн'), findsOneWidget);
    await _openMenu(tester, 'sys');
    expect(find.text('Харах'), findsOneWidget);
    expect(find.text('Хуулах'), findsOneWidget);
    expect(find.text('Устгах'), findsNothing);
  });

  testWidgets('without create or delete rights the menu only opens', (
    tester,
  ) async {
    await _pump(
      tester,
      [_t('a', 'Хүлээж авах үзлэг')],
      permissions: const ['diagnostics.view'],
    );

    expect(
      find.byKey(const ValueKey('diagnostic_templates_add')),
      findsNothing,
    );
    await _openMenu(tester, 'a');
    expect(find.text('Засах'), findsOneWidget);
    expect(find.text('Хуулах'), findsNothing);
    expect(find.text('Устгах'), findsNothing);
  });

  testWidgets('an empty list invites the first template', (tester) async {
    await _pump(tester, const []);

    expect(find.text('Оношилгоо алга байна'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('diagnostic_templates_create_first')),
      findsOneWidget,
    );
  });
}
