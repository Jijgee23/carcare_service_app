import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/domain/diagnostic.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/orders/domain/order.dart';
import 'package:carcare_service/features/orders/presentation/controllers/order_payment_controller.dart';

import '../../fakes/fake_order_repository.dart';

User _user(List<String> permissions, {bool owner = false}) => User(
  accessToken: '',
  refreshToken: '',
  id: 'user-1',
  email: 'test@example.com',
  firstName: 'Test',
  lastName: 'User',
  phone: '99001122',
  isOwner: owner,
  role: UserRole('role-1', 'Staff', permissions),
  tenant: UserTenant('tenant-1', 'Tenant'),
);

ServiceOrderDetail _order({
  String number = 'A-0001',
  PaymentStatus paymentStatus = PaymentStatus.UNPAID,
}) => ServiceOrderDetail(
  id: 'order-1',
  number: number,
  status: OrderStatus.SCHEDULED,
  paymentStatus: paymentStatus,
  totalAmount: 100.5,
  paidAmount: 0,
  totalAmountMoney: const Money('100.50'),
  paidAmountMoney: const Money('0.00'),
  createdAt: DateTime(2026),
  customer: const CustomerSummary(id: 'c', fullName: 'Customer', phone: '1'),
  vehicle: const VehicleSummary(id: 'v', plate: '1', make: 'A', model: 'B'),
  branch: const BranchSummary(id: 'b', name: 'Branch'),
  items: const [],
  reports: const [],
);

class _PaymentRepository extends FakeOrderRepository {
  _PaymentRepository() : super(seedOrders: [_order()]);

  int detailCalls = 0;
  int ledgerCalls = 0;
  int qpayCalls = 0;
  String? createdAmount;
  int createCalls = 0;
  int reverseCalls = 0;
  int qpayCreateCalls = 0;
  int qpayCheckCalls = 0;
  int qpayCancelCalls = 0;
  ({bool paid, String? message})? qpayCheckOutcome;
  bool qpayPaidAfterCheck = false;
  AppError? qpayCheckError;
  final detailResponses = <Future<Result<ServiceOrderDetail>>>[];
  Completer<Result<OrderPaymentResult>>? createCompleter;
  AppError? createError;

  @override
  Future<Result<ServiceOrderDetail>> getOrderDetail(String id) {
    detailCalls++;
    if (detailResponses.isNotEmpty) return detailResponses.removeAt(0);
    return Future.value(
      Ok(
        _order(
          paymentStatus: qpayPaidAfterCheck
              ? PaymentStatus.PAID
              : PaymentStatus.UNPAID,
        ),
      ),
    );
  }

  @override
  Future<Result<List<OrderPaymentRecord>>> getPayments(String orderId) {
    ledgerCalls++;
    return super.getPayments(orderId);
  }

  @override
  Future<Result<({bool qpayEnabled, OrderPayment? pending})>> getQPay(
    String orderId,
  ) {
    qpayCalls++;
    if (qpayPaidAfterCheck) {
      return Future.value(Ok((qpayEnabled: true, pending: null)));
    }
    return super.getQPay(orderId);
  }

  @override
  Future<Result<OrderPaymentResult>> createPayment(
    String orderId, {
    required OrderPaymentMethod method,
    required Money amount,
  }) {
    createCalls++;
    createdAmount = amount.raw;
    if (createCompleter != null) return createCompleter!.future;
    if (createError != null) return Future.value(Err(createError!));
    return super.createPayment(orderId, method: method, amount: amount);
  }

  @override
  Future<Result<OrderPaymentTotals>> reversePayment(
    String orderId,
    String paymentId,
  ) {
    reverseCalls++;
    return super.reversePayment(orderId, paymentId);
  }

  @override
  Future<Result<OrderPayment>> createQPay(String orderId) {
    qpayCreateCalls++;
    return super.createQPay(orderId);
  }

  @override
  Future<Result<({bool paid, String? message})>> checkQPay(
    String orderId,
    String paymentId,
  ) {
    qpayCheckCalls++;
    final error = qpayCheckError;
    if (error != null) return Future.value(Err(error));
    final outcome = qpayCheckOutcome;
    if (outcome != null) {
      if (outcome.paid) qpayPaidAfterCheck = true;
      return Future.value(Ok(outcome));
    }
    return super.checkQPay(orderId, paymentId);
  }

  @override
  Future<Result<void>> cancelQPay(String orderId, String paymentId) {
    qpayCancelCalls++;
    return super.cancelQPay(orderId, paymentId);
  }
}

void main() {
  test(
    'load reads detail, ledger and QPay as one authoritative snapshot',
    () async {
      final repo = _PaymentRepository();
      final controller = OrderPaymentController(
        repo: repo,
        orderId: 'order-1',
        user: _user(const ['payments.view']),
      );

      await controller.load();

      expect(controller.order?.id, 'order-1');
      expect(repo.detailCalls, 1);
      expect(repo.ledgerCalls, 1);
      expect(repo.qpayCalls, 1);
      controller.dispose();
    },
  );

  test(
    'manual payment keeps exact fractional input and refreshes all snapshots',
    () async {
      final repo = _PaymentRepository();
      final controller = OrderPaymentController(
        repo: repo,
        orderId: 'order-1',
        user: _user(const ['payments.view', 'payments.create']),
      );
      await controller.load();
      final before = (repo.detailCalls, repo.ledgerCalls, repo.qpayCalls);

      expect(
        await controller.createManual(
          amount: '10.25',
          method: OrderPaymentMethod.CASH,
        ),
        isTrue,
      );
      expect(repo.createdAmount, '10.25');
      expect(repo.detailCalls, before.$1 + 1);
      expect(repo.ledgerCalls, before.$2 + 1);
      expect(repo.qpayCalls, before.$3 + 1);
      controller.dispose();
    },
  );

  test('permission gates are independent and owner bypasses them', () async {
    final repo = _PaymentRepository();
    final viewer = OrderPaymentController(
      repo: repo,
      orderId: 'order-1',
      user: _user(const ['payments.view']),
    );
    expect(viewer.canView, isTrue);
    expect(viewer.canCreate, isFalse);
    expect(viewer.canEdit, isFalse);
    expect(viewer.canDelete, isFalse);
    expect(await viewer.createQPay(), isFalse);
    viewer.dispose();

    final owner = OrderPaymentController(
      repo: repo,
      orderId: 'order-1',
      user: _user(const [], owner: true),
    );
    expect(owner.canView, isTrue);
    expect(owner.canCreate, isTrue);
    expect(owner.canEdit, isTrue);
    expect(owner.canDelete, isTrue);
    owner.dispose();
  });

  test(
    'stale load and disposed load cannot replace or notify current state',
    () async {
      final repo = _PaymentRepository();
      final old = Completer<Result<ServiceOrderDetail>>();
      final current = Completer<Result<ServiceOrderDetail>>();
      repo.detailResponses.addAll([old.future, current.future]);
      final controller = OrderPaymentController(
        repo: repo,
        orderId: 'order-1',
        user: _user(const ['payments.view']),
      );

      final first = controller.load();
      final second = controller.load();
      current.complete(Ok(_order(number: 'CURRENT')));
      await second;
      old.complete(Ok(_order(number: 'OLD')));
      await first;
      expect(controller.order?.number, 'CURRENT');

      final pending = Completer<Result<ServiceOrderDetail>>();
      repo.detailResponses.add(pending.future);
      final disposedLoad = controller.load();
      controller.dispose();
      pending.complete(Ok(_order()));
      await disposedLoad;
    },
  );

  test(
    'server failure still refreshes and preserves the mutation error',
    () async {
      final repo = _PaymentRepository()
        ..createError = const AppError(ErrorKind.server, 'Rejected');
      final controller = OrderPaymentController(
        repo: repo,
        orderId: 'order-1',
        user: _user(const ['payments.view', 'payments.create']),
      );
      await controller.load();
      final before = repo.detailCalls;
      expect(
        await controller.createManual(
          amount: '10.25',
          method: OrderPaymentMethod.CASH,
        ),
        isFalse,
      );
      expect(repo.detailCalls, before + 1);
      expect(controller.lastError?.message, 'Rejected');
      controller.dispose();
    },
  );

  test('overlapping manual mutations suppress the duplicate request', () async {
    final repo = _PaymentRepository()
      ..createCompleter = Completer<Result<OrderPaymentResult>>();
    final controller = OrderPaymentController(
      repo: repo,
      orderId: 'order-1',
      user: _user(const ['payments.view', 'payments.create']),
    );
    await controller.load();
    final first = controller.createManual(
      amount: '10.25',
      method: OrderPaymentMethod.CASH,
    );
    expect(
      await controller.createManual(
        amount: '10.25',
        method: OrderPaymentMethod.CASH,
      ),
      isFalse,
    );
    expect(repo.createCalls, 1);
    repo.createCompleter!.complete(
      Err(const AppError(ErrorKind.server, 'Rejected')),
    );
    expect(await first, isFalse);
    controller.dispose();
  });

  test(
    'reversal and QPay create/check/cancel use their independent operations',
    () async {
      final repo = _PaymentRepository();
      final controller = OrderPaymentController(
        repo: repo,
        orderId: 'order-1',
        user: _user(const [
          'payments.view',
          'payments.create',
          'payments.edit',
          'payments.delete',
        ]),
      );
      await controller.load();
      expect(
        await controller.createManual(
          amount: '10.25',
          method: OrderPaymentMethod.CARD,
        ),
        isTrue,
      );
      final payment = controller.payments.single;
      expect(await controller.reverse(payment), isTrue);
      expect(repo.reverseCalls, 1);
      expect(
        controller.payments.single.status,
        OrderPaymentRecordStatus.CANCELLED,
      );

      expect(await controller.createQPay(), isTrue);
      expect(repo.qpayCreateCalls, 1);
      expect(await controller.checkQPay(), isFalse);
      expect(repo.qpayCheckCalls, 1);
      expect(controller.qpayCheckResult?.paid, isFalse);
      expect(await controller.cancelQPay(), isTrue);
      expect(repo.qpayCancelCalls, 1);
      controller.dispose();
    },
  );

  test(
    'QPay unpaid outcome preserves the provider message after refresh',
    () async {
      final repo = _PaymentRepository()
        ..qpayCheckOutcome = (paid: false, message: 'Төлбөр дутуу байна.');
      final controller = OrderPaymentController(
        repo: repo,
        orderId: 'order-1',
        user: _user(const [
          'payments.view',
          'payments.create',
          'payments.edit',
        ]),
      );

      await controller.load();
      expect(await controller.createQPay(), isTrue);
      expect(await controller.checkQPay(), isFalse);
      expect(controller.qpayCheckResult?.paid, isFalse);
      expect(controller.qpayCheckResult?.message, 'Төлбөр дутуу байна.');
      expect(controller.lastError, isNull);
      expect(controller.qpay?.pending, isNotNull);
      controller.dispose();
    },
  );

  test(
    'QPay paid outcome refreshes authoritative state and exposes confirmation',
    () async {
      final repo = _PaymentRepository()
        ..qpayCheckOutcome = (paid: true, message: null);
      final controller = OrderPaymentController(
        repo: repo,
        orderId: 'order-1',
        user: _user(const [
          'payments.view',
          'payments.create',
          'payments.edit',
        ]),
      );

      await controller.load();
      expect(await controller.createQPay(), isTrue);
      expect(await controller.checkQPay(), isTrue);
      expect(controller.qpayCheckResult?.paid, isTrue);
      expect(controller.qpay?.pending, isNull);
      expect(controller.order?.paymentStatus, PaymentStatus.PAID);
      controller.dispose();
    },
  );

  test(
    'QPay provider failure stays typed and visible after authoritative refresh',
    () async {
      final repo = _PaymentRepository()
        ..qpayCheckError = const AppError(
          ErrorKind.server,
          'QPay нэхэмжлэл хугацаа дууссан',
        );
      final controller = OrderPaymentController(
        repo: repo,
        orderId: 'order-1',
        user: _user(const [
          'payments.view',
          'payments.create',
          'payments.edit',
        ]),
      );

      await controller.load();
      expect(await controller.createQPay(), isTrue);
      expect(await controller.checkQPay(), isFalse);
      expect(controller.qpayCheckError?.kind, ErrorKind.server);
      expect(controller.qpayCheckError?.message, contains('хугацаа'));
      expect(controller.lastError?.message, contains('хугацаа'));
      expect(controller.qpay?.pending, isNotNull);
      controller.dispose();
    },
  );
}
