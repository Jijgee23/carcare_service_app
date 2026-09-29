import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/navigation/app_nav.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/diagnostics/domain/diagnostic.dart';
import 'package:carcare_service/features/diagnostics/domain/diagnostics_repository.dart';
import 'package:carcare_service/features/diagnostics/presentation/screens/create_template_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../services/data/fake_service_repository.dart';

class _Repo implements DiagnosticTemplateRepository {
  Map<String, dynamic>? created;

  @override
  Future<Result<DiagnosticTemplateSummary>> createTemplate(
    Map<String, dynamic> body,
  ) async {
    created = body;
    return Ok(
      DiagnosticTemplateSummary(
        id: 'tpl',
        name: body['name'] as String,
        type: DiagnosticType.INTAKE,
        version: 1,
        isActive: true,
        isSystemDefault: false,
      ),
    );
  }

  @override
  Future<Result<DiagnosticTemplateDetail>> getTemplate(String id) async =>
      const Err(AppError(ErrorKind.notFound, 'unused'));
  @override
  Future<Result<List<DiagnosticTemplateSummary>>> getTemplates({
    bool includeInactive = false,
  }) async => const Ok([]);
  @override
  Future<Result<TemplateDeleteOutcome>> deleteTemplate(String id) async =>
      const Ok(TemplateDeleteOutcome.deleted);
  @override
  Future<Result<DiagnosticTemplateSummary>> duplicateTemplate(
    String id,
  ) async => const Err(AppError(ErrorKind.unknown, 'unused'));
  @override
  Future<Result<DiagnosticTemplateSummary>> updateTemplate(
    String id,
    Map<String, dynamic> body,
  ) async => const Err(AppError(ErrorKind.unknown, 'unused'));
}

final _user = User(
  accessToken: 'token',
  refreshToken: 'refresh',
  id: 'user',
  email: 'user@example.test',
  firstName: 'Test',
  lastName: 'User',
  phone: '99001122',
  isOwner: false,
  role: UserRole('role', 'Role', const [
    'diagnostics.view',
    'diagnostics.create',
  ]),
  tenant: UserTenant('tenant', 'Tenant'),
);

/// Opens the editor from a home page, so saving has somewhere to return to.
Future<_Repo> _open(WidgetTester tester) async {
  final repo = _Repo();
  tester.view.physicalSize = const Size(430, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    GetMaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => AppNav.to(
              CreateTemplateScreen(
                repo: repo,
                categoriesRepo: FakeServiceRepository(),
                user: _user,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return repo;
}

Finder get _scroll => find.byKey(const ValueKey('template_editor_scroll'));

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find
        .descendant(of: _scroll, matching: find.byType(Scrollable))
        .first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('saving an empty form explains itself next to the fields', (
    tester,
  ) async {
    final repo = await _open(tester);

    await tester.tap(find.byKey(const ValueKey('template_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Хуудасны нэрээ оруулна уу.'), findsOneWidget);
    expect(find.text('Ангилал сонгоно уу.'), findsOneWidget);
    expect(repo.created, isNull);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('a filled form is created and the editor closes', (tester) async {
    final repo = await _open(tester);
    expect(find.text('Хадгалагдаагүй өөрчлөлт байна'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('template_name')),
      'Хүлээж авах үзлэг',
    );
    await tester.pump();
    expect(find.text('Хадгалагдаагүй өөрчлөлт байна'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('template_category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Тормозны систем').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('template_price')),
      '1234567',
    );
    await tester.pump();
    expect(find.text('1,234,567'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('template_duration')),
      '45',
    );
    await _reveal(
      tester,
      find.byKey(const ValueKey('template_type_POST_SERVICE')),
    );
    await tester.tap(find.byKey(const ValueKey('template_type_POST_SERVICE')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('template_submit')));
    await tester.pumpAndSettle();

    expect(repo.created?['name'], 'Хүлээж авах үзлэг');
    expect(repo.created?['categoryId'], 'cat-1');
    expect(repo.created?['price'], 1234567);
    expect(repo.created?['durationMin'], 45);
    expect(repo.created?['type'], 'POST_SERVICE');
    expect(repo.created?['isActive'], isTrue);
    final sections =
        (repo.created!['schema'] as Map<String, dynamic>)['sections'] as List;
    expect((sections.single as Map)['title'], 'Үндсэн үзлэг');
    expect(find.byType(CreateTemplateScreen), findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('a new question can follow an earlier answer', (tester) async {
    await _open(tester);

    await _reveal(tester, find.text('Асуулт нэмэх'));
    await tester.tap(find.text('Асуулт нэмэх'));
    await tester.pumpAndSettle();
    final added = find.widgetWithText(TextField, 'Шинэ асуулт');
    expect(added, findsOneWidget);

    // Only the new question has an earlier check question to follow.
    await _reveal(tester, find.text('— Хамаарал байхгүй —'));
    expect(find.text('— Хамаарал байхгүй —'), findsOneWidget);
    await tester.tap(find.text('— Хамаарал байхгүй —'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Кузовын байдал').last);
    await tester.pumpAndSettle();

    // It shows when the answer is the source's first option, until more
    // are ticked.
    expect(find.text('→ хариу нь:'), findsOneWidget);
    final chip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Хэвийн'),
    );
    expect(chip.selected, isTrue);
    await tester.tap(find.widgetWithText(FilterChip, 'Солих'));
    await tester.pump();
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Солих'))
          .selected,
      isTrue,
    );
  });

  testWidgets('the preview follows the questions as they are edited', (
    tester,
  ) async {
    await _open(tester);

    await _reveal(
      tester,
      find.byKey(const ValueKey('template_preview_toggle')),
    );
    await tester.tap(find.byKey(const ValueKey('template_preview_toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Нуух'), findsOneWidget);
    expect(find.text('Кузовын байдал *', findRichText: true), findsOneWidget);
  });
}
