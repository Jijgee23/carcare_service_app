/// Envelope parsing for Overview — P7-F1. Field-level tolerance lives on
/// the domain model (`overview.dart`); this file only unwraps the
/// top-level `{overview:{...}}` response envelope.
library;

import 'package:carcare_service/features/overview/domain/overview.dart';

class OverviewDto {
  const OverviewDto(this.value);
  final Overview value;

  factory OverviewDto.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const OverviewParseException('Тойм мэдээллийн хариу буруу байна.');
    }
    final json = Map<String, dynamic>.from(raw);
    final overview = json['overview'];
    if (overview is! Map) {
      throw const OverviewParseException('Тойм мэдээлэл буруу байна.');
    }
    return OverviewDto(Overview.fromJson(Map<String, dynamic>.from(overview)));
  }
}
