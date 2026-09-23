import 'package:carcare_service/features/reports/data/report_dto.dart';
import 'package:carcare_service/features/reports/domain/report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReportResultDto.fromJson', () {
    test('unwraps range and data', () {
      final dto = ReportResultDto.fromJson({
        'range': {'label': 'Энэ сар', 'key': 'this-month'},
        'data': {'totalRevenue': 500000, 'completedCount': 3},
      });
      expect(dto.value.range.label, 'Энэ сар');
      expect(dto.value.data.totalRevenue, 500000);
      expect(dto.value.data.completedCount, 3);
    });

    test('a non-map envelope throws ReportParseException', () {
      expect(
        () => ReportResultDto.fromJson('not-a-map'),
        throwsA(isA<ReportParseException>()),
      );
    });

    test('a missing range/data key throws ReportParseException', () {
      expect(
        () => ReportResultDto.fromJson({'data': {}}),
        throwsA(isA<ReportParseException>()),
      );
      expect(
        () => ReportResultDto.fromJson({'range': {}}),
        throwsA(isA<ReportParseException>()),
      );
    });
  });
}
