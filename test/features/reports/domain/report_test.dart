import 'package:carcare_service/features/reports/domain/report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReportData.fromJson', () {
    test('parses a full row set', () {
      final data = ReportData.fromJson({
        'totalRevenue': 1000000,
        'completedCount': 5,
        'avgTicket': 200000,
        'activeCount': 2,
        'statusRows': [
          {'status': 'COMPLETED', 'label': 'Дууссан', 'count': 5, 'pct': 100},
        ],
        'kindRows': [
          {'kind': 'LABOR', 'label': 'Ажил', 'total': 500000, 'pct': 50},
        ],
        'branchRows': [
          {'id': 'b-1', 'name': 'Салбар 1', 'revenue': 600000, 'count': 3},
        ],
        'techRows': [
          {'id': 'u-1', 'name': 'Бат', 'revenue': 400000, 'count': 2},
        ],
        'avgJobDurationMinutes': 45,
        'jobDurationRows': [
          {'id': 's-1', 'name': 'Даатгал', 'count': 4, 'avgMinutes': 30},
        ],
        'customerRows': [
          {
            'id': 'c-1',
            'name': 'Дорж',
            'phone': '99001122',
            'revenue': 100000,
            'count': 1,
          },
        ],
        'partRows': [
          {
            'id': 'p-1',
            'name': 'Тос',
            'sku': 'SKU1',
            'unit': 'ш',
            'qty': 2,
            'revenue': 50000,
          },
        ],
        'income': {
          'points': [
            {'label': '9-р сар', 'value': 100000},
          ],
          'changePct': 12.5,
        },
      });

      expect(data.totalRevenue, 1000000);
      expect(data.statusRows.single.status, 'COMPLETED');
      expect(data.kindRows.single.pct, 50);
      expect(data.branchRows.single.name, 'Салбар 1');
      expect(data.techRows.single.count, 2);
      expect(data.avgJobDurationMinutes, 45);
      expect(data.jobDurationRows.single.avgMinutes, 30);
      expect(data.customerRows.single.phone, '99001122');
      expect(data.partRows.single.sku, 'SKU1');
      expect(data.income.points.single.value, 100000);
      expect(data.income.changePct, 12.5);
    });

    test('missing/null fields degrade to empty defaults, never throw', () {
      final data = ReportData.fromJson(const {});
      expect(data.totalRevenue, 0);
      expect(data.completedCount, 0);
      expect(data.statusRows, isEmpty);
      expect(data.kindRows, isEmpty);
      expect(data.branchRows, isEmpty);
      expect(data.income.points, isEmpty);
      expect(data.income.changePct, isNull);
    });

    test('a non-map entry in a row list is skipped, not thrown', () {
      final data = ReportData.fromJson({
        'branchRows': [
          {'id': 'b-1'},
          'not-a-map',
          null,
        ],
      });
      expect(data.branchRows, hasLength(1));
      expect(data.branchRows.single.id, 'b-1');
    });

    test('a string numeric value is tolerated for revenue-like fields', () {
      final data = ReportData.fromJson({
        'totalRevenue': '1000000',
        'branchRows': [
          {'id': 'b-1', 'revenue': '250000.5'},
        ],
      });
      expect(data.totalRevenue, 1000000);
      expect(data.branchRows.single.revenue, 250000.5);
    });
  });

  group('ReportRange.fromJson', () {
    test('parses dates and labels', () {
      final range = ReportRange.fromJson({
        'from': '2026-09-01T00:00:00.000Z',
        'to': '2026-09-23T23:59:59.999Z',
        'label': 'Энэ сар',
        'key': 'this-month',
      });
      expect(range.from, isNotNull);
      expect(range.label, 'Энэ сар');
      expect(range.key, 'this-month');
    });

    test('missing fields degrade to null', () {
      final range = ReportRange.fromJson(const {});
      expect(range.from, isNull);
      expect(range.label, isNull);
    });
  });
}
