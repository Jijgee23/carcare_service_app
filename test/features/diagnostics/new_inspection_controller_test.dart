import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/diagnostics/domain/diagnostic.dart';
import 'package:carcare_service/features/diagnostics/domain/diagnostics_repository.dart';
import 'package:carcare_service/features/diagnostics/presentation/controllers/new_inspection_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _TemplateRepository implements DiagnosticTemplateRepository {
  final template = const DiagnosticTemplateDetail(
    id: 'template-1',
    name: 'Inspection',
    type: DiagnosticType.INTAKE,
    version: 1,
    isActive: true,
    isSystemDefault: false,
    schema: TemplateSchema(
      sections: [
        TemplateSection(
          id: 'section-1',
          title: 'Checks',
          items: [
            TemplateItem(
              id: 'gate',
              label: 'Gate',
              type: ItemType.check,
              required: true,
              options: ['Yes', 'No'],
            ),
            TemplateItem(
              id: 'conditional',
              label: 'Conditional',
              type: ItemType.text,
              required: false,
              showWhen: ShowWhen(itemId: 'gate', values: ['Yes']),
            ),
            TemplateItem(
              id: 'positioned',
              label: 'Positioned',
              type: ItemType.check,
              required: false,
              positionSet: PositionSetKey.LR,
            ),
          ],
        ),
      ],
    ),
  );

  @override
  Future<Result<List<DiagnosticTemplateSummary>>> getTemplates() async =>
      Ok([template]);
  @override
  Future<Result<DiagnosticTemplateDetail>> getTemplate(String id) async =>
      Ok(template);
  @override
  Future<Result<DiagnosticTemplateSummary>> createTemplate(
    Map<String, dynamic> body,
  ) => throw UnimplementedError();
  @override
  Future<Result<DiagnosticTemplateSummary>> updateTemplate(
    String id,
    Map<String, dynamic> body,
  ) => throw UnimplementedError();
  @override
  Future<Result<void>> deleteTemplate(String id) => throw UnimplementedError();
  @override
  Future<Result<DiagnosticTemplateSummary>> duplicateTemplate(String id) =>
      throw UnimplementedError();
}

void main() {
  test(
    'typed template preserves showWhen and positionSet in the fill model',
    () async {
      final controller = NewInspectionController(repo: _TemplateRepository());
      addTearDown(controller.dispose);

      await controller.selectTemplate('template-1');
      final items = controller.sections.single.items;
      final conditional = items.firstWhere((item) => item.id == 'conditional');
      final positioned = items.firstWhere((item) => item.id == 'positioned');

      expect(controller.isItemVisible(conditional), isFalse);
      controller.setAnswer('gate', 'Yes');
      expect(controller.isItemVisible(conditional), isTrue);
      expect(positioned.positionSet?.name, PositionSetKey.LR.name);
      expect(
        positioned.positionSet!.positions.map((position) => position.code),
        ['L', 'R'],
      );
    },
  );
}
