import 'package:carcare_service/features/overview/domain/overview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Overview.fromJson', () {
    test('parses a full payload', () {
      final overview = Overview.fromJson({
        'incomeRange': {
          'key': 'this-month',
          'from': '2026-09-01T00:00:00.000Z',
          'to': '2026-09-23T00:00:00.000Z',
          'label': 'Энэ сар',
        },
        'counts': {
          'branches': 2,
          'employees': 10,
          'customers': 100,
          'vehicles': 50,
          'openOrders': 3,
          'completedThisMonth': 20,
          'todayOrders': 4,
        },
        'trends': {
          'orders': {
            'spark': [1, 2, 3],
            'changePct': 15.0,
          },
        },
        'income': {
          'total': 5000000,
          'changePct': 8.2,
          'points': [
            {'label': '1', 'value': 100},
          ],
        },
        'subscription': {
          'plan': 'PRO',
          'status': 'ACTIVE',
          'expiresAt': '2026-12-01T00:00:00.000Z',
          'daysLeft': 60,
        },
        'planLimits': {'daily_orders': 50, 'max_vehicles': null},
        'postpaid': {'vehicleCount': 3, 'receivable': '150000'},
        'recentlyUpdatedOrders': [
          {
            'id': 'o-1',
            'number': 'A-1',
            'status': 'IN_PROGRESS',
            'updatedAt': '2026-09-20T00:00:00.000Z',
            'customerName': 'Дорж',
            'vehiclePlate': '1234УБА',
            'items': [
              {'status': 'PENDING', 'kind': 'LABOR'},
            ],
          },
        ],
      });

      expect(overview.incomeRange.label, 'Энэ сар');
      expect(overview.counts.employees, 10);
      expect(overview.trends.orders.spark, [1, 2, 3]);
      expect(overview.trends.orders.changePct, 15.0);
      expect(overview.income.total, 5000000);
      expect(overview.income.points.single.value, 100);
      expect(overview.subscription!.plan, 'PRO');
      expect(overview.subscription!.daysLeft, 60);
      expect(overview.planLimits['daily_orders'], 50);
      expect(overview.planLimits['max_vehicles'], isNull);
      expect(overview.postpaid.vehicleCount, 3);
      expect(overview.postpaid.receivable, 150000);
      expect(overview.recentlyUpdatedOrders.single.customerName, 'Дорж');
      expect(overview.recentlyUpdatedOrders.single.items.single.kind, 'LABOR');
    });

    test('missing fields degrade to defaults, never throw', () {
      final overview = Overview.fromJson(const {});
      expect(overview.counts.branches, 0);
      expect(overview.trends.orders.spark, isEmpty);
      expect(overview.subscription, isNull);
      expect(overview.planLimits, isEmpty);
      expect(overview.recentlyUpdatedOrders, isEmpty);
    });

    test('subscription:null stays null, not an empty object', () {
      final overview = Overview.fromJson({'subscription': null});
      expect(overview.subscription, isNull);
    });

    test('a non-map recentlyUpdatedOrders entry is skipped', () {
      final overview = Overview.fromJson({
        'recentlyUpdatedOrders': [
          {'id': 'o-1'},
          'garbage',
        ],
      });
      expect(overview.recentlyUpdatedOrders, hasLength(1));
    });
  });
}
