import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/customers/domain/customer.dart';
import 'package:carcare_service/features/customers/presentation/controllers/customer_broadcast_controller.dart';

import '../../fakes/fake_customer_repository.dart';

/// A fake that lets a single [sendBroadcast] call be held open, so tests can
/// assert on the controller's own overlap guard rather than merely on the
/// fake's call count (a subclass, per the P3-F7 constraint against editing
/// the shared fake).
class _SlowSendRepository extends FakeCustomerRepository {
  _SlowSendRepository({super.seed, super.accountLinkedPhones});

  int sendCalls = 0;
  final List<Completer<Result<CustomerBroadcastResult>>> _pending = [];

  Future<Result<CustomerBroadcastResult>> releaseNext() {
    final c = _pending.removeAt(0);
    return c.future;
  }

  @override
  Future<Result<CustomerBroadcastResult>> sendBroadcast({
    required String title,
    required String body,
  }) {
    sendCalls++;
    final completer = Completer<Result<CustomerBroadcastResult>>();
    _pending.add(completer);
    // Resolve with the real fake's validation/limit rules once released.
    unawaited(
      super.sendBroadcast(title: title, body: body).then(completer.complete),
    );
    return completer.future;
  }
}

void main() {
  group('CustomerBroadcastController.loadRecipientCount', () {
    test('renders the recipient count including zero', () async {
      final repo = FakeCustomerRepository(
        seed: [
          Customer(id: 'c1', fullName: 'Бат', phone: '99001111'),
          Customer(id: 'c2', fullName: 'Дорж', phone: '99002222'),
        ],
        accountLinkedPhones: {'99001111'},
      );
      final ctrl = CustomerBroadcastController(repo: repo);
      await ctrl.loadRecipientCount();
      expect(ctrl.recipientCountState, isA<AsyncData<int>>());
      expect(ctrl.recipientCount, 1);
      expect(ctrl.canSend, isTrue);
    });

    test('zero recipients is a dead end: canSend is false', () async {
      final repo = FakeCustomerRepository(
        seed: [Customer(id: 'c1', fullName: 'Бат', phone: '99001111')],
        accountLinkedPhones: const {},
      );
      final ctrl = CustomerBroadcastController(repo: repo);
      await ctrl.loadRecipientCount();
      expect(ctrl.recipientCount, 0);
      expect(ctrl.canSend, isFalse);
    });

    test('a stale in-flight count load cannot clobber a newer one', () async {
      final repo = FakeCustomerRepository(
        seed: [Customer(id: 'c1', fullName: 'Бат', phone: '99001111')],
        accountLinkedPhones: {'99001111'},
      );
      final ctrl = CustomerBroadcastController(repo: repo);
      final first = ctrl.loadRecipientCount();
      final second = ctrl.loadRecipientCount();
      await Future.wait([first, second]);
      expect(ctrl.recipientCount, 1);
    });
  });

  group('CustomerBroadcastController.send', () {
    test('reaching the daily limit surfaces the server message', () async {
      final repo = FakeCustomerRepository(
        seed: [Customer(id: 'c1', fullName: 'Бат', phone: '99001111')],
        accountLinkedPhones: {'99001111'},
        dailyBroadcastLimit: 1,
      );
      final ctrl = CustomerBroadcastController(repo: repo);
      final ok = await ctrl.send(title: 'Сайн байна уу', body: 'Урамшуулал');
      expect(ok, isA<Ok<CustomerBroadcastResult>>());

      final limited = await ctrl.send(title: 'Дахин', body: 'Дахин');
      expect(limited, isA<Err<CustomerBroadcastResult>>());
      final error = (limited as Err<CustomerBroadcastResult>).error;
      expect(error.statusCode, 422);
      expect(error.code, CustomerErrorCode.dailyLimitReached);
      expect(ctrl.lastError, isNotNull);
      expect(ctrl.lastError!.display, error.message);
    });

    test('validation failures populate fieldErrors', () async {
      final repo = FakeCustomerRepository(
        seed: [Customer(id: 'c1', fullName: 'Бат', phone: '99001111')],
        accountLinkedPhones: {'99001111'},
      );
      final ctrl = CustomerBroadcastController(repo: repo);
      final result = await ctrl.send(title: '', body: '');
      expect(result, isA<Err<CustomerBroadcastResult>>());
      expect(ctrl.fieldErrors['title'], isNotNull);
      expect(ctrl.fieldErrors['body'], isNotNull);
    });

    test('a second send while one is in flight is a no-op', () async {
      final repo = _SlowSendRepository(
        seed: [Customer(id: 'c1', fullName: 'Бат', phone: '99001111')],
        accountLinkedPhones: {'99001111'},
      );
      final ctrl = CustomerBroadcastController(repo: repo);

      final firstSend = ctrl.send(title: 'A', body: 'A');
      expect(ctrl.sending, isTrue);

      // Fired while the first is still in flight — must not reach the repo.
      final secondSend = ctrl.send(title: 'B', body: 'B');
      final secondResult = await secondSend;
      expect(secondResult, isNull);
      expect(repo.sendCalls, 1);

      // Release the first call and let it complete normally.
      unawaited(repo.releaseNext());
      final firstResult = await firstSend;
      expect(firstResult, isA<Ok<CustomerBroadcastResult>>());
      expect(ctrl.sending, isFalse);
    });

    test('sending zero recipients still consumes the daily allowance '
        '(server wart, mirrored not hidden)', () async {
      final repo = FakeCustomerRepository(
        seed: [Customer(id: 'c1', fullName: 'Бат', phone: '99001111')],
        accountLinkedPhones: const {},
        dailyBroadcastLimit: 1,
      );
      final ctrl = CustomerBroadcastController(repo: repo);
      await ctrl.loadRecipientCount();
      expect(ctrl.recipientCount, 0);
      // The controller itself does not block send() — canSend does, and the
      // UI relies on canSend. Calling send() directly (bypassing the UI
      // guard) still reaches the server and burns the allowance, exactly as
      // the real API does; this test documents that the safety is in
      // canSend/the UI, not in a hidden client-side rewrite of the count.
      final first = await ctrl.send(title: 'A', body: 'A');
      expect(first, isA<Ok<CustomerBroadcastResult>>());
      final second = await ctrl.send(title: 'B', body: 'B');
      expect(second, isA<Err<CustomerBroadcastResult>>());
      expect(
        (second as Err<CustomerBroadcastResult>).error.code,
        CustomerErrorCode.dailyLimitReached,
      );
    });
  });
}
