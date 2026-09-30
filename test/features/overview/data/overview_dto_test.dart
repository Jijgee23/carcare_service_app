import 'package:carservice_business/features/overview/data/overview_dto.dart';
import 'package:carservice_business/features/overview/domain/overview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OverviewDto.fromJson', () {
    test('unwraps the overview envelope', () {
      final dto = OverviewDto.fromJson({
        'overview': {
          'counts': {'branches': 1},
        },
      });
      expect(dto.value.counts.branches, 1);
    });

    test('a non-map root throws OverviewParseException', () {
      expect(
        () => OverviewDto.fromJson('not-a-map'),
        throwsA(isA<OverviewParseException>()),
      );
    });

    test('a missing overview key throws OverviewParseException', () {
      expect(
        () => OverviewDto.fromJson({'wrong': {}}),
        throwsA(isA<OverviewParseException>()),
      );
    });
  });
}
