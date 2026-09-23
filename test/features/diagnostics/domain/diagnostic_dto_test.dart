import 'package:carcare_service/features/diagnostics/data/diagnostic_dto.dart';
import 'package:carcare_service/features/diagnostics/domain/diagnostic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'template parsing tolerates divergent optional fields and retains schema',
    () {
      final value = DiagnosticTemplateDetailDto.fromJson({
        'id': 't1',
        'name': 7,
        'type': 'FUTURE',
        'version': 'bad',
        'isActive': 'yes',
        'isSystemDefault': true,
        'price': '12.5',
        'durationMin': '30',
        'updatedAt': 'invalid',
        'schema': {
          'sections': [
            {
              'id': 's',
              'title': 'Engine',
              'items': [
                {
                  'id': 'i',
                  'label': 'Oil',
                  'type': 'check',
                  'required': true,
                  'options': ['OK'],
                  'positionSet': 'LR',
                  'showWhen': {
                    'itemId': 'x',
                    'values': ['YES'],
                  },
                },
              ],
            },
          ],
        },
      }).value;
      expect(value.type, DiagnosticType.unknown);
      expect(value.version, 1);
      expect(value.isActive, isTrue);
      expect(value.isSystemDefault, isTrue);
      expect(value.price, 12.5);
      expect(value.durationMin, isNull);
      expect(value.updatedAt, isNull);
      final item = value.schema.sections.single.items.single;
      expect(item.positionSet, PositionSetKey.LR);
      expect(item.showWhen!.values, ['YES']);
    },
  );

  test(
    'report parsing tolerates bad optional fields and retains maxSeverity',
    () {
      final value = DiagnosticReportDetailDto.fromJson({
        'id': 'r1',
        'createdAt': 'bad',
        'templateVersion': null,
        'filledById': 'staff-1',
        'mileageAtReport': 'x',
        'maxSeverity': 'HIGH',
        'data': {
          'i': {
            'value': 'Засах',
            'photos': ['a', 4],
            'note': 5,
          },
        },
        'template': {
          'id': 't1',
          'name': 'Inspection',
          'type': 'INTAKE',
          'schema': {'sections': []},
        },
        'customer': {},
        'vehicle': {},
        'branch': {},
      }).value;
      expect(value.createdAt, isNull);
      expect(value.templateVersion, 1);
      expect(value.maxSeverity, 'HIGH');
      expect(value.filledById, 'staff-1');
      expect(value.data['i']!.photos, ['a']);
      expect(value.data['i']!.note, isNull);
      expect(value.overallStatus, CheckStatus.danger);
    },
  );

  test('report summary retains severity and author id when present', () {
    final value = DiagnosticReportSummaryDto.fromJson({
      'id': 'r2',
      'maxSeverity': 'WARN',
      'filledBy': {'id': 'staff-2'},
    }).value;
    expect(value.maxSeverity, 'WARN');
    expect(value.filledById, 'staff-2');
  });

  test('missing structurally required id throws typed exception', () {
    expect(
      () => DiagnosticTemplateSummaryDto.fromJson({'name': 'x'}),
      throwsA(isA<DiagnosticParseException>()),
    );
  });
}
