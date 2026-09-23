import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/core/domain/diagnostic.dart';
import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/features/orders/domain/order.dart';
import 'package:carcare_service/features/orders/domain/orders_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_order_repository.dart';

ServiceOrderDetail _postpaidOrder({
  required String id,
  required String number,
  required String vehicleId,
  required String plate,
  required DateTime scheduledAt,
  required OrderStatus status,
  required PaymentStatus paymentStatus,
  required String total,
  required String paid,
}) {
  return ServiceOrderDetail(
    id: id,
    number: number,
    status: status,
    paymentStatus: paymentStatus,
    isPostpaid: true,
    scheduledAt: scheduledAt,
    createdAt: scheduledAt.subtract(const Duration(days: 1)),
    customer: CustomerSummary(
      id: 'customer-$vehicleId',
      fullName: 'Customer $vehicleId',
      phone: '99001122',
    ),
    vehicle: VehicleSummary(
      id: vehicleId,
      plate: plate,
      make: 'Toyota',
      model: 'Prius',
    ),
    branch: const BranchSummary(id: 'branch-1', name: 'Толгойт салбар'),
    totalAmountMoney: Money(total),
    paidAmountMoney: Money(paid),
    items: const [],
    reports: const [],
  );
}

void main() {
  test('getOrders lists the seeded order', () async {
    final repo = FakeOrderRepository();

    final result = await repo.getOrders();

    expect(result, isA<Ok>());
    final page = (result as Ok).value;
    expect(page.items, hasLength(1));
    expect(page.items.single.number, 'A-0001');
  });

  test('getOrderDetail returns the seeded order by id', () async {
    final repo = FakeOrderRepository();

    final result = await repo.getOrderDetail('order-1');

    expect(result, isA<Ok>());
    expect((result as Ok).value.id, 'order-1');
  });

  test('getOrderDetail reports not-found for an unknown id', () async {
    final repo = FakeOrderRepository();

    final result = await repo.getOrderDetail('missing');

    expect(result, isA<Err>());
  });

  test('createOrder appends a new order visible to getOrders', () async {
    final repo = FakeOrderRepository();

    await repo.createOrder(
      branchId: 'branch-1',
      customerId: 'cust-1',
      vehicleId: 'veh-1',
    );
    final result = await repo.getOrders();

    expect((result as Ok).value.items, hasLength(2));
  });

  test('updateStatus mutates the stored order', () async {
    final repo = FakeOrderRepository();

    final result = await repo.updateStatus('order-1', OrderStatus.IN_PROGRESS);

    expect((result as Ok).value.status, OrderStatus.IN_PROGRESS);
    final detail = await repo.getOrderDetail('order-1');
    expect((detail as Ok).value.status, OrderStatus.IN_PROGRESS);
  });

  test(
    'addItem then updateItem then removeItem retains cancelled item',
    () async {
      final repo = FakeOrderRepository();

      final added = await repo.addItem(
        'order-1',
        kind: ItemKind.PART,
        description: 'Тос',
        quantity: 2,
        unitPrice: 15000,
      );
      final item = (added as Ok).value;
      expect(item.total, 30000);

      final updated = await repo.updateItem('order-1', item.id, quantity: 3);
      expect((updated as Ok).value.total, 45000);

      final removed = await repo.removeItem('order-1', item.id);
      expect(removed, isA<Ok>());
      final detail = await repo.getOrderDetail('order-1');
      expect((detail as Ok<ServiceOrderDetail>).value.items, hasLength(1));
      expect((detail).value.items.single.status, ServiceItemStatus.CANCELLED);
    },
  );

  test('cancelItem retains item with cancellation metadata', () async {
    final repo = FakeOrderRepository();
    final added = await repo.addItem(
      'order-1',
      kind: ItemKind.PART,
      description: 'Тос',
      quantity: 1,
      unitPrice: 10,
    ) as Ok<ServiceItem>;
    await repo.cancelItem('order-1', added.value.id);
    final detail =
        await repo.getOrderDetail('order-1') as Ok<ServiceOrderDetail>;
    expect(detail.value.items.single.status, ServiceItemStatus.CANCELLED);
    expect(detail.value.items.single.cancelledById, 'fake-user');
  });

  test('schedule mutations persist on the stored detail', () async {
    final repo = FakeOrderRepository();
    final scheduled = DateTime(2026, 9, 19, 11);
    await repo.rescheduleOrder('order-1', scheduled);
    await repo.reviseExpectedFinish(
      'order-1',
      scheduled.add(const Duration(hours: 2)),
    );
    final detail =
        await repo.getOrderDetail('order-1') as Ok<ServiceOrderDetail>;
    expect(detail.value.scheduledAt, scheduled);
    expect(
      detail.value.expectedFinishAt,
      scheduled.add(const Duration(hours: 2)),
    );
  });

  test(
    'postpaid filtering uses explicit order attribute, not payment status',
    () async {
      final repo = FakeOrderRepository(seedPostpaid: true);
      final postpaid = await repo.getPostpaid();
      expect(postpaid, isA<Ok<PostpaidPage>>());
      expect(
        (postpaid as Ok<PostpaidPage>).value.orders.single.isPostpaid,
        isTrue,
      );
      await repo.createPayment(
        'order-1',
        method: OrderPaymentMethod.CASH,
        amount: const Money('100'),
      );
      final stillPostpaid = await repo.getPostpaid();
      expect((stillPostpaid as Ok<PostpaidPage>).value.orders, hasLength(1));
    },
  );

  test(
    'postpaid aggregates exclude cancelled orders but preserve history',
    () async {
      final repo = FakeOrderRepository(seedPostpaid: true);
      await repo.updateStatus('order-1', OrderStatus.CANCELLED);
      final result = await repo.getPostpaid() as Ok<PostpaidPage>;
      expect(result.value.orders, hasLength(1));
      expect(result.value.vehicles, hasLength(1));
      expect(result.value.vehicles.single.orderCount, 0);
      expect(result.value.summary.orderCount, 0);
      expect(result.value.summary.totalAmountMoney.raw, '0');
    },
  );

  test(
    'postpaid filters affect history only, not all-time aggregates',
    () async {
      final repo = FakeOrderRepository(
        seedOrders: [
          _postpaidOrder(
            id: 'postpaid-1',
            number: 'P-0001',
            vehicleId: 'veh-1',
            plate: '1234ABC',
            scheduledAt: DateTime(2026, 1, 10),
            status: OrderStatus.SCHEDULED,
            paymentStatus: PaymentStatus.UNPAID,
            total: '100.00',
            paid: '20.00',
          ),
          _postpaidOrder(
            id: 'postpaid-2',
            number: 'P-0002',
            vehicleId: 'veh-1',
            plate: '1234ABC',
            scheduledAt: DateTime(2026, 2, 10),
            status: OrderStatus.COMPLETED,
            paymentStatus: PaymentStatus.PAID,
            total: '200.00',
            paid: '200.00',
          ),
          _postpaidOrder(
            id: 'postpaid-3',
            number: 'P-0003',
            vehicleId: 'veh-2',
            plate: '5678XYZ',
            scheduledAt: DateTime(2026, 1, 10),
            status: OrderStatus.CANCELLED,
            paymentStatus: PaymentStatus.PAID,
            total: '300.00',
            paid: '300.00',
          ),
        ],
      );

      final result = await repo.getPostpaid(
        query: PostpaidQuery(
          paymentStatus: PaymentStatus.UNPAID,
          dateFrom: DateTime(2026, 1, 10),
          dateTo: DateTime(2026, 1, 10),
        ),
      ) as Ok<PostpaidPage>;

      expect(result.value.orders, hasLength(1));
      expect(result.value.orders.single.id, 'postpaid-1');
      expect(result.value.pagination.total, 1);
      expect(result.value.summary.orderCount, 2);
      expect(result.value.summary.totalAmountMoney.raw, '300.00');
      expect(result.value.summary.paidAmountMoney.raw, '220.00');
      expect(result.value.summary.balanceAmountMoney.raw, '80.00');

      final vehicles = {
        for (final vehicle in result.value.vehicles) vehicle.id: vehicle,
      };
      expect(vehicles, hasLength(2));
      expect(vehicles['veh-1']!.orderCount, 2);
      expect(vehicles['veh-1']!.totalAmountMoney.raw, '300.00');
      expect(vehicles['veh-1']!.paidAmountMoney.raw, '220.00');
      expect(vehicles['veh-1']!.balanceAmountMoney.raw, '80.00');
      expect(vehicles['veh-2']!.orderCount, 0);
      expect(vehicles['veh-2']!.totalAmountMoney.raw, '0');
      expect(vehicles['veh-2']!.paidAmountMoney.raw, '0');
      expect(vehicles['veh-2']!.balanceAmountMoney.raw, '0');
    },
  );

  test('fake list search and date filters use canonical fields', () async {
    final repo = FakeOrderRepository();
    expect(
      (await repo.getOrders(
        q: '99001122',
      ) as Ok<PagedResult<ServiceOrderSummary>>).value.items,
      hasLength(1),
    );
    expect(
      (await repo.getOrders(
        q: 'Toyota',
      ) as Ok<PagedResult<ServiceOrderSummary>>).value.items,
      hasLength(1),
    );
    expect(
      (await repo.getOrders(
        dateFrom: DateTime(2026, 1, 10),
        dateTo: DateTime(2026, 1, 10),
      ) as Ok<PagedResult<ServiceOrderSummary>>).value.items,
      hasLength(1),
    );
    expect(
      (await repo.getOrders(
        dateFrom: DateTime(2026, 1, 11),
      ) as Ok<PagedResult<ServiceOrderSummary>>).value.items,
      isEmpty,
    );
  });

  test('Money item path preserves decimal strings and item history', () async {
    final repo = FakeOrderRepository();
    final added = await repo.addItemMoney(
      'order-1',
      kind: ItemKind.PART,
      description: 'Part',
      quantity: const Money('1.250'),
      unitPrice: const Money('10.00'),
    ) as Ok<ServiceItem>;
    expect(added.value.quantityMoney?.raw, '1.250');
    expect(added.value.unitPriceMoney?.raw, '10.00');
    expect(added.value.totalMoney?.raw, '12.50000');
    expect(
      (await repo.getItemHistory(
        'order-1',
      ) as Ok<OrderItemHistoryPage>).value.items,
      isEmpty,
    );
    await repo.cancelItem('order-1', added.value.id);
    final history = await repo.getItemHistory('order-1');
    expect(
      (history as Ok<OrderItemHistoryPage>).value.items.single.totalMoney?.raw,
      '12.50000',
    );
  });

  test(
    'ledger create/reverse is stateful and QPay pending is cancellable',
    () async {
      final repo = FakeOrderRepository();
      final created = await repo.createPayment(
        'order-1',
        method: OrderPaymentMethod.CASH,
        amount: const Money('10.00'),
      ) as Ok<OrderPaymentResult>;
      expect(
        (await repo.getPayments(
          'order-1',
        ) as Ok<List<OrderPaymentRecord>>).value,
        hasLength(1),
      );
      final reversed = await repo.reversePayment(
        'order-1',
        created.value.payment.id,
      ) as Ok<OrderPaymentTotals>;
      expect(reversed.value.paidAmountMoney.raw, '0');
      final detail =
          await repo.getOrderDetail('order-1') as Ok<ServiceOrderDetail>;
      expect(detail.value.paymentStatus, PaymentStatus.UNPAID);
      expect(detail.value.paidAmount, 0);
      final qpay = await repo.createQPay('order-1') as Ok<OrderPayment>;
      expect(
        (await repo.getQPay('order-1') as Ok).value.pending?.id,
        qpay.value.id,
      );
      await repo.cancelQPay('order-1', qpay.value.id);
      expect((await repo.getQPay('order-1') as Ok).value.pending, isNull);
    },
  );

  test(
    'item status and QPay cancellation reject cancellation or wrong ids',
    () async {
      final repo = FakeOrderRepository();
      final added = await repo.addItem(
        'order-1',
        kind: ItemKind.PART,
        description: 'Part',
        quantity: 1,
        unitPrice: 1,
      ) as Ok<ServiceItem>;
      expect(
        await repo.changeItemStatus(
          'order-1',
          added.value.id,
          ServiceItemStatus.CANCELLED,
        ),
        isA<Err>(),
      );
      final qpay = await repo.createQPay('order-1') as Ok<OrderPayment>;
      expect(await repo.cancelQPay('order-1', 'wrong'), isA<Err>());
      expect(
        (await repo.getQPay('order-1') as Ok).value.pending?.id,
        qpay.value.id,
      );
      expect(await repo.cancelQPay('missing', qpay.value.id), isA<Err>());
      expect(
        (await repo.getQPay('order-1') as Ok).value.pending?.id,
        qpay.value.id,
      );
    },
  );

  test(
    'createOrder rejects appointmentId and estimatedDurationMinutes together',
    () async {
      final repo = FakeOrderRepository();
      final before = await repo.getOrders();
      final beforeCount =
          (before as Ok<PagedResult<ServiceOrderSummary>>).value.items.length;

      final result = await repo.createOrder(
        branchId: 'branch-1',
        customerId: 'cust-1',
        vehicleId: 'veh-1',
        appointmentId: 'appt-1',
        estimatedDurationMinutes: 45,
      );

      expect(result, isA<Err>());
      final after = await repo.getOrders();
      expect(
        (after as Ok<PagedResult<ServiceOrderSummary>>).value.items,
        hasLength(beforeCount),
      );
    },
  );

  test('createOrder accepts appointmentId alone', () async {
    final repo = FakeOrderRepository();

    final result = await repo.createOrder(
      branchId: 'branch-1',
      customerId: 'cust-1',
      vehicleId: 'veh-1',
      appointmentId: 'appt-1',
    );

    expect(result, isA<Ok>());
  });

  test('createOrder accepts estimatedDurationMinutes alone', () async {
    final repo = FakeOrderRepository();

    final result = await repo.createOrder(
      branchId: 'branch-1',
      customerId: 'cust-1',
      vehicleId: 'veh-1',
      estimatedDurationMinutes: 45,
    );

    expect(result, isA<Ok>());
  });

  test(
    'bulk methods mutate known ids and report deterministic partial failures',
    () async {
      final repo = FakeOrderRepository();
      final status = await repo.bulkChangeStatus([
        'order-1',
        'missing',
      ], OrderStatus.IN_PROGRESS) as Ok<BulkOrderResult>;
      expect(status.value.succeeded, ['order-1']);
      expect(status.value.failed.single.orderId, 'missing');
      final assignment = await repo.bulkAssign([
        'order-1',
        'missing',
      ], 'user-1') as Ok<BulkOrderResult>;
      expect(assignment.value.succeeded, ['order-1']);
      expect(assignment.value.failed.single.code, 'NOT_FOUND');
    },
  );
}
