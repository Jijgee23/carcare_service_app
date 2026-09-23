/// Envelope parsing for Reports — P7-F1. Field-level tolerance lives on the
/// domain models (`report.dart`); this file only unwraps the top-level
/// response envelope.
library;

import 'package:carcare_service/features/reports/domain/report.dart';

typedef JsonMap = Map<String, dynamic>;

JsonMap _map(Object? value, String label) {
  if (value is! Map) throw ReportParseException('$label буруу байна.');
  return Map<String, dynamic>.from(value);
}

/// `GET /api/v1/reports` — `{range:{...}, data:{...}}`.
class ReportResultDto {
  const ReportResultDto(this.value);
  final ReportResult value;

  factory ReportResultDto.fromJson(Object? raw) {
    final json = _map(raw, 'тайлангийн хариу');
    return ReportResultDto(
      ReportResult(
        range: ReportRange.fromJson(_map(json['range'], 'range')),
        data: ReportData.fromJson(_map(json['data'], 'data')),
      ),
    );
  }
}
