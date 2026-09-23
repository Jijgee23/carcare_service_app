import 'package:carcare_service/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_diagnostic_repository.dart';

void main() {
  test('getTemplates lists the seeded template', () async {
    final repo = FakeDiagnosticRepository();

    final templates = await repo.getTemplates();

    expect(templates, hasLength(1));
    expect(templates.single.name, 'Ерөнхий үзлэг');
  });

  test('getTemplateDetail returns the full schema for a known id', () async {
    final repo = FakeDiagnosticRepository();

    final detail = await repo.getTemplateDetail('tpl-1');

    expect(detail, isNotNull);
    expect(detail!.schema.sections.single.items.single.id, 'item-1');
  });

  test('getTemplateDetail returns null for an unknown id', () async {
    final repo = FakeDiagnosticRepository();

    expect(await repo.getTemplateDetail('missing'), isNull);
  });

  test('getReports lists the seeded report', () async {
    final repo = FakeDiagnosticRepository();

    final page = await repo.getReports();

    expect(page.items, hasLength(1));
    expect(page.items.single.id, 'report-1');
  });

  test('getReportDetail hydrates the summary into a full detail', () async {
    final repo = FakeDiagnosticRepository();

    final detail = await repo.getReportDetail('report-1');

    expect(detail, isNotNull);
    expect(detail!.customer.id, 'cust-1');
  });

  test('deleteReport removes it from subsequent listings', () async {
    final repo = FakeDiagnosticRepository();

    final result = await repo.deleteReport('report-1');

    expect(result, isA<Ok>());
    final page = await repo.getReports();
    expect(page.items, isEmpty);
  });

  test('deleteReport reports not-found for an unknown id', () async {
    final repo = FakeDiagnosticRepository();

    final result = await repo.deleteReport('missing');

    expect(result, isA<Err>());
  });
}
