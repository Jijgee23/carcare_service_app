import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/diagnostics/domain/diagnostic.dart';
import 'package:carcare_service/features/diagnostics/domain/diagnostics_repository.dart';
import 'package:carcare_service/features/diagnostics/presentation/controllers/create_template_controller.dart';
import 'package:carcare_service/features/diagnostics/presentation/screens/create_template_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TemplateRepo implements DiagnosticTemplateRepository {
  Map<String, dynamic>? created;
  Map<String, dynamic>? updated;
  String? updatedId;
  DiagnosticTemplateDetail? template;
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
  Future<Result<DiagnosticTemplateSummary>> duplicateTemplate(
    String id,
  ) async => const Err(AppError(ErrorKind.unknown, 'unused'));
  @override
  Future<Result<DiagnosticTemplateDetail>> getTemplate(String id) async =>
      template == null
      ? const Err(AppError(ErrorKind.notFound, 'missing'))
      : Ok(template!);
  @override
  Future<Result<List<DiagnosticTemplateSummary>>> getTemplates() async =>
      const Ok([]);
  @override
  Future<Result<void>> deleteTemplate(String id) async => const Ok(null);
  @override
  Future<Result<DiagnosticTemplateSummary>> updateTemplate(
    String id,
    Map<String, dynamic> body,
  ) async {
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

DiagnosticTemplateDetail _detail({bool systemDefault = false}) =>
    DiagnosticTemplateDetail(
      id: 'template-1',
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

void main() {
  late _TemplateRepo repo;
  late CreateTemplateController controller;

  setUp(() {
    repo = _TemplateRepo();
    controller = CreateTemplateController(repo: repo)..init();
    controller.sections.first.titleCtrl.text = 'Үндсэн';
  });
  tearDown(() => controller.dispose());

  test('showWhen only accepts earlier non-positioned check items and valid options', () {
    final sectionId = controller.sections.first.id;
    final source = controller.newItem()..label = 'Төлөв';
    source.options = ['OK', 'Засах'];
    controller.addItem(sectionId, source);
    final dependent = controller.newItem()..label = 'Тайлбар';
    dependent.type = ItemType.text;
    controller.addItem(sectionId, dependent);

    expect(controller.priorCheckItems(sectionId, dependent.id), [source]);
    expect(controller.hasValidShowWhen, isTrue);
    dependent.showWhen = ShowWhen(itemId: source.id, values: ['Засах']);
    expect(controller.hasValidShowWhen, isTrue);
    dependent.showWhen = ShowWhen(itemId: source.id, values: ['missing']);
    expect(controller.hasValidShowWhen, isFalse);
    dependent.showWhen = ShowWhen(itemId: 'later', values: ['OK']);
    expect(controller.hasValidShowWhen, isFalse);
  });

  test('showWhen survives serialization through template create', () async {
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
    final sections =
        (repo.created!['schema'] as Map<String, dynamic>)['sections'] as List;
    final savedItems =
        (sections.single as Map<String, dynamic>)['items'] as List;
    expect((savedItems[1] as Map<String, dynamic>)['showWhen'], {
      'itemId': source.id,
      'values': ['Засах'],
    });
  });

  test('invalid showWhen prevents repository submission', () async {
    final sectionId = controller.sections.first.id;
    final dependent = controller.newItem()..label = 'Тайлбар';
    dependent.type = ItemType.text;
    dependent.showWhen = const ShowWhen(itemId: 'not-earlier', values: ['OK']);
    controller.addItem(sectionId, dependent);

    expect(await controller.submit(), isNull);
    expect(repo.created, isNull);
  });

  test('reordering and positionSet editing remain supported', () {
    final sectionId = controller.sections.first.id;
    final first = controller.newItem()..label = 'A';
    final second = controller.newItem()..label = 'B';
    controller.addItem(sectionId, first);
    controller.addItem(sectionId, second);
    controller.moveItemUp(sectionId, second.id);
    expect(controller.sections.first.items.first.id, second.id);
    final positioned = first.copyWith(positionSet: PositionSetKey.LR);
    controller.updateItem(sectionId, positioned);
    expect(controller.sections.first.items.last.positionSet, PositionSetKey.LR);
  });

  test('edit mode loads existing fields and updates template schema', () async {
    repo.template = _detail();
    final editController = CreateTemplateController(
      repo: repo,
      templateId: 'template-1',
    );
    await editController.init();
    addTearDown(editController.dispose);

    expect(editController.nameCtrl.text, 'Бүрэн загвар');
    expect(editController.descCtrl.text, 'Тайлбар хадгалах');
    expect(editController.priceCtrl.text, '12000.0');
    expect(editController.durationCtrl.text, '45');
    expect(editController.version, 4);
    expect(editController.sections.single.id, 'section-1');
    expect(editController.sections.single.items[1].showWhen?.itemId, 'check-1');

    editController.nameCtrl.text = 'Шинэ нэр';
    final result = await editController.submit();

    expect(result?.name, 'Шинэ нэр');
    expect(repo.updatedId, 'template-1');
    expect(repo.created, isNull);
    final sections =
        (repo.updated!['schema'] as Map<String, dynamic>)['sections'] as List;
    final savedItems =
        (sections.single as Map<String, dynamic>)['items'] as List;
    expect((savedItems[0] as Map<String, dynamic>)['options'], ['OK', 'Засах']);
    expect((savedItems[1] as Map<String, dynamic>)['showWhen'], {
      'itemId': 'check-1',
      'values': ['Засах'],
    });
  });

  test('system-default templates cannot be submitted for mutation', () async {
    repo.template = _detail(systemDefault: true);
    final editController = CreateTemplateController(
      repo: repo,
      templateId: 'template-1',
    );
    await editController.init();
    addTearDown(editController.dispose);

    expect(editController.isSystemDefault, isTrue);
    expect(await editController.submit(), isNull);
    expect(repo.updated, isNull);
    expect(repo.created, isNull);
  });

  testWidgets('template editor denies users without diagnostics.view', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CreateTemplateScreen(repo: repo, user: _user(const [])),
      ),
    );
    expect(find.text('Энэ үйлдэлд эрх байхгүй байна'), findsOneWidget);
    expect(find.text('СХЕМ БҮТЭЦ'), findsNothing);
  });

  testWidgets('template editor opens for diagnostics.view users', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CreateTemplateScreen(
          repo: repo,
          user: _user(const ['diagnostics.view']),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('СХЕМ БҮТЭЦ'), findsOneWidget);
    expect(find.text('Энэ үйлдэлд эрх байхгүй байна'), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('template save is visible only with diagnostics.create', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CreateTemplateScreen(
          repo: repo,
          user: _user(const ['diagnostics.view', 'diagnostics.create']),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('edit loads template but requires diagnostics.edit to save', (
    tester,
  ) async {
    repo.template = _detail();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CreateTemplateScreen(
          templateId: 'template-1',
          repo: repo,
          user: _user(const ['diagnostics.view']),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Загвар засах'), findsOneWidget);
    expect(find.text('Бүрэн загвар'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('edit save is visible with diagnostics.edit', (tester) async {
    repo.template = _detail();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CreateTemplateScreen(
          templateId: 'template-1',
          repo: repo,
          user: _user(const ['diagnostics.view', 'diagnostics.edit']),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('system-default template is displayed as immutable', (
    tester,
  ) async {
    repo.template = _detail(systemDefault: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CreateTemplateScreen(
          templateId: 'template-1',
          repo: repo,
          user: _user(const ['diagnostics.view', 'diagnostics.edit']),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Системийн загварыг өөрчлөх боломжгүй байна'),
      findsOneWidget,
    );
    expect(find.byType(ElevatedButton), findsNothing);
  });
}
