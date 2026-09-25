import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/features/diagnostics/domain/diagnostic.dart';

typedef JsonMap = Map<String, dynamic>;
JsonMap _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
String? _str(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
String _id(JsonMap j) {
  final id = _str(j['id']);
  if (id == null) {
    throw const DiagnosticParseException('id талбар буруу байна.');
  }
  return id;
}

int _int(Object? v, [int fallback = 0]) => v is int
    ? v
    : v is num
    ? v.toInt()
    : fallback;
double? _double(Object? v) => v is num
    ? v.toDouble()
    : v is String
    ? double.tryParse(v)
    : null;
DateTime? _date(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;
List<String>? _strings(Object? v) =>
    v is List ? v.whereType<String>().toList(growable: false) : null;
List<JsonMap> _maps(Object? v) => v is List
    ? v
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false)
    : const [];

class DiagnosticTemplateSummaryDto {
  const DiagnosticTemplateSummaryDto(this.value);
  final DiagnosticTemplateSummary value;
  factory DiagnosticTemplateSummaryDto.fromJson(Object? raw) {
    final j = _map(raw);
    return DiagnosticTemplateSummaryDto(
      DiagnosticTemplateSummary(
        id: _id(j),
        name: _str(j['name']) ?? '',
        description: _str(j['description']),
        type: DiagnosticType.fromJson(j['type']),
        version: _int(j['version'], 1),
        isActive: j['isActive'] is bool ? j['isActive'] as bool : true,
        isSystemDefault: j['isSystemDefault'] == true,
        price: _double(j['price']),
        durationMin: j['durationMin'] is num ? _int(j['durationMin']) : null,
        updatedAt: _date(j['updatedAt']),
        categoryId: _str(j['categoryId']),
      ),
    );
  }
}

class DiagnosticTemplateDetailDto {
  const DiagnosticTemplateDetailDto(this.value);
  final DiagnosticTemplateDetail value;
  factory DiagnosticTemplateDetailDto.fromJson(Object? raw) {
    final j = _map(raw),
        summary = DiagnosticTemplateSummaryDto.fromJson(raw).value;
    final schema = _map(j['schema']);
    final sections = _maps(schema['sections'])
        .map(
          (s) => TemplateSection(
            id: _str(s['id']) ?? '',
            title: _str(s['title']) ?? '',
            items: _maps(s['items'])
                .map((i) {
                  final sw = _map(i['showWhen']);
                  return TemplateItem(
                    id: _str(i['id']) ?? '',
                    label: _str(i['label']) ?? '',
                    type: ItemType.fromJson(i['type']),
                    required: i['required'] == true,
                    options: _strings(i['options']),
                    showWhen: _str(sw['itemId']) == null
                        ? null
                        : ShowWhen(
                            itemId: _str(sw['itemId'])!,
                            values: _strings(sw['values']) ?? const [],
                          ),
                    positionSet: PositionSetKey.fromJson(i['positionSet']),
                  );
                })
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
    return DiagnosticTemplateDetailDto(
      DiagnosticTemplateDetail(
        id: summary.id,
        name: summary.name,
        description: summary.description,
        type: summary.type,
        version: summary.version,
        isActive: summary.isActive,
        isSystemDefault: summary.isSystemDefault,
        price: summary.price,
        durationMin: summary.durationMin,
        updatedAt: summary.updatedAt,
        categoryId: summary.categoryId,
        schema: TemplateSchema(sections: sections),
      ),
    );
  }
}

class DiagnosticTemplateListDto {
  const DiagnosticTemplateListDto(this.items);
  final List<DiagnosticTemplateSummary> items;
  factory DiagnosticTemplateListDto.fromJson(Object? raw) {
    final list = _map(raw)['templates'];
    return DiagnosticTemplateListDto(
      list is List
          ? list
                .whereType<Map>()
                .map((e) => DiagnosticTemplateSummaryDto.fromJson(e).value)
                .toList(growable: false)
          : const [],
    );
  }
}

class DiagnosticTemplateEnvelopeDto {
  const DiagnosticTemplateEnvelopeDto(this.value);
  final DiagnosticTemplateDetail value;
  factory DiagnosticTemplateEnvelopeDto.fromJson(Object? raw) =>
      DiagnosticTemplateEnvelopeDto(
        DiagnosticTemplateDetailDto.fromJson(_map(raw)['template']).value,
      );
}

class DiagnosticReportSummaryDto {
  const DiagnosticReportSummaryDto(this.value);
  final DiagnosticReportSummary value;
  factory DiagnosticReportSummaryDto.fromJson(Object? raw) {
    final j = _map(raw),
        c = _map(j['customer']),
        v = _map(j['vehicle']),
        b = _map(j['branch']),
        t = _map(j['template']),
        u = _map(j['filledBy']);
    final customer = CustomerSummary(
      id: _str(c['id']) ?? '',
      fullName: _str(c['fullName']),
      phone: _str(c['phone']) ?? '',
      email: _str(c['email']),
    );
    final vehicle = VehicleSummary(
      id: _str(v['id']) ?? '',
      plate: _str(v['plate']) ?? '',
      vin: _str(v['vin']),
      make: _str(v['make']) ?? '',
      model: _str(v['model']) ?? '',
      year: v['year'] is num ? _int(v['year']) : null,
      mileage: v['mileage'] is num ? _int(v['mileage']) : null,
      customerId: _str(v['customerId']),
      customer: c.isEmpty ? null : customer,
    );
    return DiagnosticReportSummaryDto(
      DiagnosticReportSummary(
        id: _id(j),
        maxSeverity: _str(j['maxSeverity']),
        filledById: _str(j['filledById']) ?? _str(u['id']),
        createdAt: _date(j['createdAt']),
        templateVersion: _int(j['templateVersion'], 1),
        mileageAtReport: j['mileageAtReport'] is num
            ? _int(j['mileageAtReport'])
            : null,
        orderId: _str(j['orderId']),
        template: ReportTemplateSummary(
          id: _str(t['id']) ?? '',
          name: _str(t['name']) ?? '',
          type: DiagnosticType.fromJson(t['type']),
        ),
        customer: customer,
        vehicle: vehicle,
        branch: BranchSummary(
          id: _str(b['id']) ?? '',
          name: _str(b['name']) ?? '',
          address: _str(b['address']),
        ),
        filledBy: u.isEmpty
            ? null
            : UserSummary(
                id: _str(u['id']) ?? '',
                firstName: _str(u['firstName']) ?? '',
                lastName: _str(u['lastName']) ?? '',
              ),
      ),
    );
  }
}

class DiagnosticReportDetailDto {
  const DiagnosticReportDetailDto(this.value);
  final DiagnosticReportDetail value;
  factory DiagnosticReportDetailDto.fromJson(Object? raw) {
    final j = _map(raw),
        summary = DiagnosticReportSummaryDto.fromJson(raw).value,
        template = DiagnosticTemplateDetailDto.fromJson(j['template']).value;
    final data = <String, ReportEntry>{};
    final rawData = _map(j['data']);
    rawData.forEach((k, v) {
      final e = _map(v);
      data[k] = ReportEntry(
        value: e['value'],
        photos: _strings(e['photos']),
        note: _str(e['note']),
      );
    });
    return DiagnosticReportDetailDto(
      DiagnosticReportDetail(
        id: summary.id,
        filledById: _str(j['filledById']) ?? summary.filledById,
        createdAt: summary.createdAt,
        templateVersion: summary.templateVersion,
        maxSeverity: _str(j['maxSeverity']),
        mileageAtReport: summary.mileageAtReport,
        notes: _str(j['notes']),
        signatureUrl: _str(j['signatureUrl']),
        orderId: summary.orderId,
        data: data,
        template: template,
        customer: summary.customer,
        vehicle: summary.vehicle,
        branch: summary.branch,
        filledBy: summary.filledBy,
      ),
    );
  }
}

class DiagnosticReportPageDto {
  const DiagnosticReportPageDto(this.items, this.pagination);
  final List<DiagnosticReportSummary> items;
  final PaginationMeta pagination;
  factory DiagnosticReportPageDto.fromJson(Object? raw) {
    final j = _map(raw), p = _map(_map(raw)['pagination']);
    final page = _int(p['page'], 1),
        size = _int(p['pageSize'], 30),
        total = _int(p['total']);
    return DiagnosticReportPageDto(
      _maps(j['reports'])
          .map((e) => DiagnosticReportSummaryDto.fromJson(e).value)
          .toList(growable: false),
      PaginationMeta(
        page: page,
        pageSize: size,
        total: total,
        totalPages: _int(p['totalPages']),
        hasPrev: p['hasPrev'] == true,
        hasNext: p['hasNext'] == true,
      ),
    );
  }
}

class DiagnosticReportIdDto {
  const DiagnosticReportIdDto(this.id);
  final String id;
  factory DiagnosticReportIdDto.fromJson(Object? raw) => DiagnosticReportIdDto(
    _str(_map(_map(raw)['report'])['id']) ??
        (throw const DiagnosticParseException('id талбар буруу байна.')),
  );
}
