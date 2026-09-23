import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/core/domain/working_branch_scope.dart';
import 'package:carcare_service/core/domain/diagnostic.dart';
import 'package:carcare_service/core/network/working_branch_interceptor.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/orders/domain/order.dart';
import 'package:carcare_service/features/orders/domain/orders_error_codes.dart';
import 'package:carcare_service/features/orders/presentation/controllers/order_detail_controller.dart';
import 'package:carcare_service/features/shell/domain/working_branch.dart';
import 'package:carcare_service/features/shell/presentation/controllers/working_branch_controller.dart';

import '../../fakes/fake_order_repository.dart';

class _DetailRepository extends FakeOrderRepository {
  final detailResponses = <Completer<Result<ServiceOrderDetail>>>[];
  final detailRequestIds = <String>[];
  final assignableBranches = <String?>[];
  final assignableResponses = <Completer<Result<List<AssignableUser>>>>[];
  OrderStatus? lastStatus;
  int? lastDurationMinutes;
  String? lastAssignedToId;
  bool returnConfirmationForExpectedFinish = false;
  bool returnConfirmationForReschedule = false;
  int expectedFinishAttempts = 0;
  int rescheduleAttempts = 0;

  @override
  Future<Result<ServiceOrderDetail>> getOrderDetail(String id) {
    detailRequestIds.add(id);
    if (detailResponses.isNotEmpty) return detailResponses.removeAt(0).future;
    return super.getOrderDetail(id);
  }

  @override
  Future<Result<ServiceOrderDetail>> updateStatus(
    String id,
    OrderStatus status, {
    int? durationMinutes,
  }) async {
    lastStatus = status;
    lastDurationMinutes = durationMinutes;
    return super.updateStatus(id, status, durationMinutes: durationMinutes);
  }

  @override
  Future<Result<ServiceOrderDetail>> updateAssignment(
    String id,
    String? assignedToId,
  ) async {
    lastAssignedToId = assignedToId;
    return super.updateAssignment(id, assignedToId);
  }

  @override
  Future<Result<List<AssignableUser>>> getAssignableUsers({String? branchId}) {
    assignableBranches.add(branchId);
    if (assignableResponses.isNotEmpty) {
      return assignableResponses.removeAt(0).future;
    }
    return super.getAssignableUsers(branchId: branchId);
  }

  @override
  Future<Result<OrderScheduleResult>> reviseExpectedFinish(
    String id,
    DateTime? expectedFinishAt, {
    bool confirmed = false,
  }) async {
    expectedFinishAttempts++;
    if (returnConfirmationForExpectedFinish && !confirmed) {
      return const Err(
        AppError(
          ErrorKind.unknown,
          'Outside hours',
          statusCode: 409,
          code: OrdersErrorCodes.confirmationRequired,
        ),
      );
    }
    return super.reviseExpectedFinish(
      id,
      expectedFinishAt,
      confirmed: confirmed,
    );
  }

  @override
  Future<Result<OrderScheduleResult>> rescheduleOrder(
    String id,
    DateTime scheduledAt, {
    bool confirmed = false,
  }) async {
    rescheduleAttempts++;
    if (returnConfirmationForReschedule && !confirmed) {
      return const Err(
        AppError(
          ErrorKind.unknown,
          'Outside hours',
          statusCode: 409,
          code: OrdersErrorCodes.confirmationRequired,
        ),
      );
    }
    return super.rescheduleOrder(id, scheduledAt, confirmed: confirmed);
  }
}

class _BranchStore implements WorkingBranchSelectionStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? selection) async => value = selection;

  @override
  Future<void> clear() async => value = null;
}

ServiceOrderDetail _detail({OrderStatus status = OrderStatus.SCHEDULED}) =>
    ServiceOrderDetail(
      id: 'order-1',
      number: 'A-0001',
      status: status,
      paymentStatus: PaymentStatus.UNPAID,
      scheduledAt: DateTime(2026, 1, 10),
      createdAt: DateTime(2026, 1, 9),
      customer: const CustomerSummary(
        id: 'cust-1',
        fullName: 'Customer',
        phone: '99001122',
      ),
      vehicle: const VehicleSummary(
        id: 'vehicle-1',
        plate: '1234ABC',
        make: 'Toyota',
        model: 'Prius',
      ),
      branch: const BranchSummary(id: 'branch-1', name: 'Branch'),
      items: const [],
      reports: const [],
    );

void main() {
  test('stale detail response cannot replace the newer order', () async {
    final repo = _DetailRepository();
    final old = Completer<Result<ServiceOrderDetail>>();
    final newer = Completer<Result<ServiceOrderDetail>>();
    repo.detailResponses.addAll([old, newer]);
    final controller = OrderDetailController(repo: repo);

    final first = controller.load('order-1');
    final second = controller.load('order-1');
    newer.complete(Ok(_detail(status: OrderStatus.IN_PROGRESS)));
    await second;
    old.complete(Ok(_detail()));
    await first;

    expect(controller.order?.status, OrderStatus.IN_PROGRESS);
    controller.dispose();
  });

  test('status mutation forwards duration and reloads detail', () async {
    final repo = _DetailRepository();
    final controller = OrderDetailController(repo: repo);
    await controller.load('order-1');

    final result = await controller.updateStatus(
      OrderStatus.IN_PROGRESS,
      durationMinutes: 90,
    );

    expect(result, isA<Ok<ServiceOrderDetail>>());
    expect(repo.lastStatus, OrderStatus.IN_PROGRESS);
    expect(repo.lastDurationMinutes, 90);
    expect(controller.order?.status, OrderStatus.IN_PROGRESS);
    controller.dispose();
  });

  test(
    'successful status mutation stays visible when detail refresh fails',
    () async {
      final repo = _DetailRepository();
      final controller = OrderDetailController(repo: repo);
      await controller.load('order-1');
      repo.detailResponses.add(
        Completer<Result<ServiceOrderDetail>>()..complete(
          const Err(AppError(ErrorKind.server, 'Detail refresh failed')),
        ),
      );

      final result = await controller.updateStatus(OrderStatus.IN_PROGRESS);

      expect(result, isA<Ok<ServiceOrderDetail>>());
      expect(controller.detailState, isA<AsyncData<ServiceOrderDetail>>());
      expect(controller.order?.status, OrderStatus.IN_PROGRESS);
      expect(controller.detailRefreshError?.kind, ErrorKind.server);
      controller.dispose();
    },
  );

  test(
    'confirmation metadata is narrowly recognized for schedule retries',
    () async {
      final repo = _DetailRepository()..returnConfirmationForReschedule = true;
      final controller = OrderDetailController(repo: repo);
      await controller.load('order-1');

      final first = await controller.rescheduleOrder(DateTime(2026, 1, 11));
      expect(first, isA<Err<OrderScheduleResult>>());
      expect(
        OrderDetailController.requiresConfirmation(
          (first as Err<OrderScheduleResult>).error,
        ),
        isTrue,
      );
      expect(repo.rescheduleAttempts, 1);
      controller.dispose();
    },
  );

  test('working-branch switch invalidates detail and roster state', () async {
    final repo = _DetailRepository();
    final branch =
        WorkingBranchController(
            repository: _TestBranchRepository(),
            store: _BranchStore(),
          )
          ..options = const WorkingBranchOptions(
            branches: [
              SwitchableBranch(id: 'branch-1', name: 'One'),
              SwitchableBranch(id: 'branch-2', name: 'Two'),
            ],
            allowAll: true,
            lockedBranchId: null,
          )
          ..selection = 'branch-1';
    final controller = OrderDetailController(
      repo: repo,
      branchController: branch,
    );
    await controller.load('order-1');
    final before = repo.detailRequestIds.length;

    await branch.select('branch-2');
    await Future<void>.delayed(Duration.zero);

    expect(repo.detailRequestIds.length, greaterThan(before));
    expect(controller.assignableUsersState.valueOrNull, isNull);
    controller.dispose();
    branch.dispose();
  });

  test(
    'working-branch switch reloads a requested roster without stale overwrite',
    () async {
      final repo = _DetailRepository();
      final branch =
          WorkingBranchController(
              repository: _TestBranchRepository(),
              store: _BranchStore(),
            )
            ..options = const WorkingBranchOptions(
              branches: [
                SwitchableBranch(id: 'branch-1', name: 'One'),
                SwitchableBranch(id: 'branch-2', name: 'Two'),
              ],
              allowAll: false,
              lockedBranchId: null,
            )
            ..selection = 'branch-1';
      final controller = OrderDetailController(
        repo: repo,
        branchController: branch,
      );
      await controller.load('order-1');
      final oldRoster = Completer<Result<List<AssignableUser>>>();
      final newRoster = Completer<Result<List<AssignableUser>>>();
      repo.assignableResponses.addAll([oldRoster, newRoster]);
      final first = controller.loadAssignableUsers();
      await Future<void>.delayed(Duration.zero);

      final switched = branch.select('branch-2');
      await Future<void>.delayed(Duration.zero);
      newRoster.complete(
        const Ok([
          AssignableUser(id: 'new', firstName: 'New', lastName: 'User'),
        ]),
      );
      await Future<void>.delayed(Duration.zero);
      oldRoster.complete(
        const Ok([
          AssignableUser(id: 'old', firstName: 'Old', lastName: 'User'),
        ]),
      );
      await Future.wait([first, switched]);

      expect(repo.assignableBranches, ['branch-1', 'branch-2']);
      expect(controller.assignableUsersState.valueOrNull!.single.id, 'new');
      controller.dispose();
      branch.dispose();
    },
  );
}

class _TestBranchRepository implements WorkingBranchRepository {
  @override
  Future<WorkingBranchOptions> fetchOptions() async =>
      const WorkingBranchOptions(
        branches: [],
        allowAll: true,
        lockedBranchId: null,
      );
}
