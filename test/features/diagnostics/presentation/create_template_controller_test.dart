import 'package:carservice_business/features/services/domain/service.dart';
import 'package:carservice_business/app/theme/app_theme.dart';
import 'package:carservice_business/core/domain/user.dart';
import 'package:carservice_business/core/errors/app_error.dart';
import 'package:carservice_business/core/utils/result.dart';
import 'package:carservice_business/features/diagnostics/domain/diagnostic.dart';
import 'package:carservice_business/features/diagnostics/domain/diagnostics_repository.dart';
import 'package:carservice_business/features/diagnostics/presentation/controllers/create_template_controller.dart';
import 'package:carservice_business/features/diagnostics/presentation/screens/create_template_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../services/data/fake_service_repository.dart';

class _TemplateRepo implements DiagnosticTemplateRepository {
  Map<String, dynamic>? created;
  Map<String, dynamic>? updated;
  String? updatedId;
  DiagnosticTemplateDetail? template;

  /// When set, create/update fail with it.
  AppError? failure;

  @override
  Future<Result<DiagnosticTemplateSummary>> createTemplate(
    Map<String, dynamic> body,
  ) async {
    if (failure != null) return Err(failure!);
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
  Future<Result<DiagnosticTemplateSummary>> duplicateTemplate(
    String id,
  ) async => const Err(AppError(ErrorKind.unknown, 'unused'));
  @override
  Future<Result<DiagnosticTemplateDetail>> getTemplate(String id) async =>
      template == null
      ? const Err(AppError(ErrorKind.notFound, 'missing'))
      : Ok(template!);
  @override
  Future<Result<List<DiagnosticTemplateSummary>>> getTemplates({
    bool includeInactive = false,
  }) async => const Ok([]);
  @override
  Future<Result<TemplateDeleteOutcome>> deleteTemplate(String id) async =>
      const Ok(TemplateDeleteOutcome.deleted);
  @override
  Future<Result<DiagnosticTemplateSummary>> updateTemplate(
    String id,
    Map<String, dynamic> body,
  ) async {
    if (failure != null) return Err(failure!);
    updatedId = id;
    updated = body;
    return Ok(
      DiagnosticTemplateSummary(
        id: id,
        name: body['name'] as String,
        type: DiagnosticType.ROUTINE,
        version: 2,
        isActive: body['isActive'] as bool,
        isSystemDefault: false,
      ),
    );
  }
}

DiagnosticTemplateDetail _detail({
  bool systemDefault = false,
  String? categoryId = 'cat-1',
}) => DiagnosticTemplateDetail(
  id: 'template-1',
  categoryId: categoryId,
  name: 'Бүрэн загвар',
  description: 'Тайлбар хадгалах',
  type: DiagnosticType.ROUTINE,
  version: 4,
  isActive: true,
  isSystemDefault: systemDefault,
  price: 12000,
  durationMin: 45,
  schema: TemplateSchema(
    sections: [
      TemplateSection(
        id: 'section-1',
        title: 'Ерөнхий',
        items: [
          const TemplateItem(
            id: 'check-1',
            label: 'Төлөв',
            type: ItemType.check,
            required: true,
            options: ['OK', 'Засах'],
          ),
          const TemplateItem(
            id: 'text-1',
            label: 'Тайлбар',
            type: ItemType.text,
            required: false,
            showWhen: ShowWhen(itemId: 'check-1', values: ['Засах']),
          ),
        ],
      ),
    ],
  ),
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

List<Map<String, dynamic>> _savedItems(Map<String, dynamic> body) {
  final sections = (body['schema'] as Map<String, dynamic>)['sections'] as List;
  return [
    for (final section in sections)
      for (final item in (section as Map<String, dynamic>)['items'] as List)
        item as Map<String, dynamic>,
  ];
}

void main() {
  late _TemplateRepo repo;
  late CreateTemplateController controller;

  setUp(() {
    repo = _TemplateRepo();
    controller = CreateTemplateController(
      repo: repo,
      categoriesRepo: FakeServiceRepository(),
    )..init();
  });
  tearDown(() => controller.dispose());

  /// What the form needs besides a valid structure.
  void fillDetails() {
    controller.nameCtrl.text = 'Шинэ загвар';
    controller.setCategory('cat-1');
  }

  test('a new template starts like the web: one section, one required '
      'check question with the default answers', () {
    final section = controller.sections.single;
    expect(section.titleCtrl.text, 'Үндсэн үзлэг');
    final item = section.items.single;
    expect(item.label, 'Кузовын байдал');
    expect(item.type, ItemType.check);
    expect(item.isRequired, isTrue);
    expect(item.options, defaultCheckOptions);
    expect(defaultCheckOptions, ['Хэвийн', 'Анхаарах', 'Солих']);
    expect(controller.type, DiagnosticType.INTAKE);
    expect(controller.isActive, isTrue);
    expect(controller.dirty, isFalse);

    controller.addSection();
    expect(controller.sections.last.titleCtrl.text, 'Шинэ хэсэг');
    expect(controller.newItem().label, 'Шинэ асуулт');
    expect(controller.dirty, isTrue);
  });

  test('showWhen only accepts earlier non-positioned check items and valid '
      'options', () {
    final sectionId = controller.sections.first.id;
    final seeded = controller.sections.first.items.single;
    final source = controller.newItem()..label = 'Төлөв';
    source.options = ['OK', 'Засах'];
    controller.addItem(sectionId, source);
    final dependent = controller.newItem()..label = 'Тайлбар';
    dependent.type = ItemType.text;
    controller.addItem(sectionId, dependent);

    expect(controller.priorCheckItems(sectionId, dependent.id), [
      seeded,
      source,
    ]);
    expect(controller.hasValidShowWhen, isTrue);
    dependent.showWhen = ShowWhen(itemId: source.id, values: ['Засах']);
    expect(controller.hasValidShowWhen, isTrue);
    expect(controller.dependencyOf(sectionId, dependent), source);
    dependent.showWhen = ShowWhen(itemId: source.id, values: ['missing']);
    expect(
      controller.schemaProblem,
      '"Тайлбар" асуултын хамаарлын "missing" утга өмнөх асуултын сонголтод '
      'алга.',
    );
    dependent.showWhen = const ShowWhen(itemId: 'later', values: ['OK']);
    expect(controller.hasValidShowWhen, isFalse);
    expect(controller.dependencyOf(sectionId, dependent), isNull);

    // A positioned check question has one answer per position, so it can
    // no longer drive the dependency.
    dependent.showWhen = ShowWhen(itemId: source.id, values: ['Засах']);
    controller.updateItem(
      sectionId,
      source.copyWith(positionSet: PositionSetKey.LR),
    );
    expect(controller.dependencyOf(sectionId, dependent), isNull);
    expect(controller.hasValidShowWhen, isFalse);
  });

  test('showWhen survives serialization through template create', () async {
    fillDetails();
    final sectionId = controller.sections.first.id;
    final source = controller.newItem()..label = 'Төлөв';
    source.options = ['OK', 'Засах'];
    controller.addItem(sectionId, source);
    final dependent = controller.newItem()..label = 'Тайлбар';
    dependent.type = ItemType.text;
    dependent.showWhen = ShowWhen(itemId: source.id, values: ['Засах']);
    controller.addItem(sectionId, dependent);

    final result = await controller.submit();

    expect(result?.id, 'tpl');
    final saved = _savedItems(repo.created!);
    expect(saved[2]['showWhen'], {
      'itemId': source.id,
      'values': ['Засах'],
    });
    expect(saved[2].containsKey('options'), isFalse);
    expect(controller.dirty, isFalse);
  });

  test('invalid showWhen prevents repository submission', () async {
    fillDetails();
    final sectionId = controller.sections.first.id;
    final dependent = controller.newItem()..label = 'Тайлбар';
    dependent.type = ItemType.text;
    dependent.showWhen = const ShowWhen(itemId: 'not-earlier', values: ['OK']);
    controller.addItem(sectionId, dependent);

    expect(await controller.submit(), isNull);
    expect(repo.created, isNull);
    expect(controller.schemaError, contains('асуултын хамаарал буруу'));
  });

  test('validation mirrors the server before any request', () async {
    controller.nameCtrl.text = ' ';
    expect(await controller.submit(), isNull);
    expect(controller.fieldErrors, {
      'name': 'Хуудасны нэрээ оруулна уу.',
      'categoryId': 'Ангилал сонгоно уу.',
    });

    fillDetails();
    final section = controller.sections.first;
    section.titleCtrl.text = '';
    expect(await controller.submit(), isNull);
    expect(controller.fieldErrors, isEmpty);
    expect(controller.schemaError, '1 дэх хэсгийн нэр хоосон байна.');

    section.titleCtrl.text = 'Үндсэн';
    section.items.single.label = '';
    expect(await controller.submit(), isNull);
    expect(controller.schemaError, '"Үндсэн" хэсгийн 1-р асуулт хоосон.');

    controller.removeItem(section.id, section.items.single.id);
    expect(await controller.submit(), isNull);
    expect(
      controller.schemaError,
      '"Үндсэн" хэсэгт дор хаяж нэг асуулт хэрэгтэй.',
    );

    controller.removeSection(section.id);
    expect(await controller.submit(), isNull);
    expect(controller.schemaError, 'Хуудсанд дор хаяж нэг хэсэг байх ёстой.');
    expect(repo.created, isNull);
  });

  test('a 422 lands its field errors on the fields', () async {
    fillDetails();
    repo.failure = const AppError(
      ErrorKind.unknown,
      'Хүсэлт буруу.',
      statusCode: 422,
      fieldErrors: {'price': 'Үнэ буруу.', 'schema': 'Хуудасны бүтэц буруу.'},
    );

    expect(await controller.submit(), isNull);
    expect(controller.fieldErrors, {'price': 'Үнэ буруу.'});
    expect(controller.schemaError, 'Хуудасны бүтэц буруу.');
    expect(controller.formError, isNull);

    repo.failure = const AppError(
      ErrorKind.forbidden,
      'Хязгаарт хүрсэн байна.',
    );
    expect(await controller.submit(), isNull);
    expect(controller.formError, 'Хязгаарт хүрсэн байна.');
  });

  test('a check question always carries options; other types none', () {
    final sectionId = controller.sections.first.id;
    final item = controller.sections.first.items.single;

    controller.updateItem(sectionId, item.copyWith(type: ItemType.text));
    final text = controller.sections.first.items.single;
    expect(text.options, isEmpty);
    expect(text.toJson().containsKey('options'), isFalse);

    controller.updateItem(sectionId, text.copyWith(type: ItemType.check));
    final check = controller.sections.first.items.single;
    expect(check.options, defaultCheckOptions);
    expect(check.toJson()['options'], defaultCheckOptions);
  });

  test('price and duration are sent as numbers', () async {
    fillDetails();
    controller.priceCtrl.text = '25,000';
    controller.durationCtrl.text = '30';

    await controller.submit();

    expect(repo.created?['price'], 25000);
    expect(repo.created?['durationMin'], 30);
  });

  test('reordering and positionSet editing remain supported', () {
    final sectionId = controller.sections.first.id;
    final first = controller.newItem()..label = 'A';
    final second = controller.newItem()..label = 'B';
    controller.addItem(sectionId, first);
    controller.addItem(sectionId, second);
    controller.moveItemUp(sectionId, second.id);
    expect(controller.sections.first.items.map((i) => i.label), [
      'Кузовын байдал',
      'B',
      'A',
    ]);
    final positioned = first.copyWith(positionSet: PositionSetKey.LR);
    controller.updateItem(sectionId, positioned);
    expect(controller.sections.first.items.last.positionSet, PositionSetKey.LR);

    controller.addSection();
    final added = controller.sections.last.id;
    controller.moveSectionUp(added);
    expect(controller.sections.first.id, added);
  });

  test('edit mode loads existing fields and updates template schema', () async {
    repo.template = _detail();
    final editController = CreateTemplateController(
      repo: repo,
      categoriesRepo: FakeServiceRepository(),
      templateId: 'template-1',
    );
    await editController.init();
    addTearDown(editController.dispose);

    expect(editController.nameCtrl.text, 'Бүрэн загвар');
    expect(editController.descCtrl.text, 'Тайлбар хадгалах');
    expect(editController.priceCtrl.text, '12,000');
    expect(editController.durationCtrl.text, '45');
    expect(editController.version, 4);
    expect(editController.sections.single.id, 'section-1');
    expect(editController.sections.single.items[1].showWhen?.itemId, 'check-1');
    expect(editController.dirty, isFalse, reason: 'loading is not an edit');

    editController.nameCtrl.text = 'Шинэ нэр';
    expect(editController.dirty, isTrue);
    final result = await editController.submit();

    expect(result?.name, 'Шинэ нэр');
    expect(repo.updatedId, 'template-1');
    expect(repo.created, isNull);
    expect(repo.updated?['price'], 12000);
    final saved = _savedItems(repo.updated!);
    expect(saved[0]['options'], ['OK', 'Засах']);
    expect(saved[1]['showWhen'], {
      'itemId': 'check-1',
      'values': ['Засах'],
    });
  });

  test('system-default templates cannot be submitted for mutation', () async {
    repo.template = _detail(systemDefault: true);
    final editController = CreateTemplateController(
      repo: repo,
      categoriesRepo: FakeServiceRepository(),
      templateId: 'template-1',
    );
    await editController.init();
    addTearDown(editController.dispose);

    expect(editController.readOnly, isTrue);
    expect(editController.canSubmit, isFalse);
    expect(await editController.submit(), isNull);
    expect(repo.updated, isNull);
    expect(repo.created, isNull);
  });

  Widget host(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

  testWidgets('template editor denies users without diagnostics.view', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        CreateTemplateScreen(
          repo: repo,
          categoriesRepo: FakeServiceRepository(),
          user: _user(const []),
        ),
      ),
    );
    expect(find.text('Энэ үйлдэлд эрх байхгүй байна'), findsOneWidget);
    expect(find.text('Хуудасны бүтэц'), findsNothing);
  });

  testWidgets('template editor opens for diagnostics.view users, without a '
      'save button', (tester) async {
    await tester.pumpWidget(
      host(
        CreateTemplateScreen(
          repo: repo,
          categoriesRepo: FakeServiceRepository(),
          user: _user(const ['diagnostics.view']),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Шинэ оношилгоо'), findsOneWidget);
    expect(find.text('Үндсэн мэдээлэл'), findsOneWidget);
    expect(find.text('01 / 03'), findsOneWidget);
    expect(find.text('Энэ үйлдэлд эрх байхгүй байна'), findsNothing);
    expect(find.byKey(const ValueKey('template_submit')), findsNothing);
  });

  testWidgets('template save is visible only with diagnostics.create', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        CreateTemplateScreen(
          repo: repo,
          categoriesRepo: FakeServiceRepository(),
          user: _user(const ['diagnostics.view', 'diagnostics.create']),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('template_submit')), findsOneWidget);
    expect(find.text('Үүсгэх'), findsOneWidget);
  });

  testWidgets('edit loads template but requires diagnostics.edit to save', (
    tester,
  ) async {
    repo.template = _detail();
    await tester.pumpWidget(
      host(
        CreateTemplateScreen(
          templateId: 'template-1',
          repo: repo,
          categoriesRepo: FakeServiceRepository(),
          user: _user(const ['diagnostics.view']),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Оношилгоо засах'), findsOneWidget);
    expect(find.text('v4 · Бүрэн загвар'), findsOneWidget);
    expect(find.byKey(const ValueKey('template_submit')), findsNothing);
  });

  testWidgets('edit save is visible with diagnostics.edit', (tester) async {
    repo.template = _detail();
    await tester.pumpWidget(
      host(
        CreateTemplateScreen(
          templateId: 'template-1',
          repo: repo,
          categoriesRepo: FakeServiceRepository(),
          user: _user(const ['diagnostics.view', 'diagnostics.edit']),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('template_submit')), findsOneWidget);
    expect(find.text('Хадгалах'), findsOneWidget);
  });

  testWidgets('a system-default template opens as a read-only preview', (
    tester,
  ) async {
    repo.template = _detail(systemDefault: true);
    await tester.pumpWidget(
      host(
        CreateTemplateScreen(
          templateId: 'template-1',
          repo: repo,
          categoriesRepo: FakeServiceRepository(),
          user: _user(const ['diagnostics.view', 'diagnostics.edit']),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Оношилгоо харах'), findsOneWidget);
    expect(find.textContaining('системийн үндсэн загвар'), findsOneWidget);
    // The preview renders the questions; the editor panels do not show.
    expect(find.text('Төлөв *', findRichText: true), findsOneWidget);
    expect(find.text('Үндсэн мэдээлэл'), findsNothing);
    expect(find.byKey(const ValueKey('template_submit')), findsNothing);

    // "Тайлбар" shows only once "Төлөв" is answered "Засах".
    expect(find.text('Тайлбар', findRichText: true), findsNothing);
    await tester.tap(find.text('Засах'));
    await tester.pump();
    expect(find.text('Тайлбар', findRichText: true), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('template_preview_clear')));
    await tester.pump();
    expect(find.text('Тайлбар', findRichText: true), findsNothing);
  });

  test('categories load, a category is required, and it is sent', () async {
    await Future<void>.delayed(Duration.zero); // let init()'s load finish
    expect(controller.categories.map((c) => c.id), ['cat-1']);

    controller.nameCtrl.text = 'Шинэ загвар';
    expect(await controller.submit(), isNull); // no category yet
    expect(controller.fieldErrors['categoryId'], 'Ангилал сонгоно уу.');

    controller.setCategory('cat-1');
    await controller.submit();
    expect(repo.created?['categoryId'], 'cat-1');
  });

  test(
    'edit keeps the template category, even if it was deactivated',
    () async {
      repo.template = _detail(categoryId: 'cat-old');
      final editController = CreateTemplateController(
        repo: repo,
        categoriesRepo: FakeServiceRepository(
          categories: [
            FakeServiceRepository.seedCategory(),
            const Category(id: 'cat-old', name: 'Хуучин', isActive: false),
          ],
        ),
        templateId: 'template-1',
      );
      await editController.init();
      await Future<void>.delayed(Duration.zero);
      addTearDown(editController.dispose);

      expect(editController.categoryId, 'cat-old');
      expect(
        editController.selectableCategories.map((c) => c.id),
        containsAll(['cat-1', 'cat-old']),
      );
      await editController.submit();
      expect(repo.updated?['categoryId'], 'cat-old');
    },
  );
}
