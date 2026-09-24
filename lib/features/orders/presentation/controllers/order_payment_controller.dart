import 'package:flutter/foundation.dart';

import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/services/auth_storage.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/orders/domain/order.dart';
import 'package:carcare_service/features/orders/domain/orders_repository.dart';

/// Owns the payment screen's complete server-authoritative state.
///
/// The controller intentionally does not mutate a [ServiceOrderDetail] after a
/// write. Every successful mutation is followed by a fresh detail, ledger and
/// QPay read, which keeps the payment status and remaining amount owned by the
/// API rather than by a stale widget calculation.
class OrderPaymentController extends ChangeNotifier {
  OrderPaymentController({
    required this.repo,
    required this.orderId,
    this._user,
  });

  final OrdersRepository repo;
  final String orderId;
  final User? _user;

  AsyncValue<ServiceOrderDetail> detailState = const AsyncLoading();
  AsyncValue<List<OrderPaymentRecord>> paymentsState = const AsyncLoading();
  AsyncValue<QPayState> qpayState = const AsyncLoading();
  AppError? lastError;
  QPayCheckResult? qpayCheckResult;
  AppError? qpayCheckError;

  bool _disposed = false;
  bool _operationActive = false;
  int _generation = 0;
  bool _loaded = false;

  ServiceOrderDetail? get order => detailState.valueOrNull;
  List<OrderPaymentRecord> get payments =>
      paymentsState.valueOrNull ?? const <OrderPaymentRecord>[];
  QPayState? get qpay => qpayState.valueOrNull;
  bool get isLoading =>
      detailState is AsyncLoading ||
      paymentsState is AsyncLoading ||
      qpayState is AsyncLoading;
  bool get isBusy => _operationActive;

  User? get _currentUser {
    if (_user != null) return _user;
    try {
      return Authenticator.user;
    } catch (_) {
      // Unit tests and pre-auth routes may not have opened Hive yet.
      return null;
    }
  }

  bool can(String permission) {
    final user = _currentUser;
    return user?.isOwner == true ||
        (user?.role?.permissions.contains(permission) ?? false);
  }

  bool get canView => can('payments.view');
  bool get canCreate => can('payments.create');
  bool get canEdit => can('payments.edit');
  bool get canDelete => can('payments.delete');

  Future<void> load() => refresh(initial: true);

  Future<void> refresh({bool initial = false}) async {
    if (_disposed || !canView) return;
    final generation = ++_generation;
    if (initial || !_loaded) {
      detailState = const AsyncLoading();
      paymentsState = const AsyncLoading();
      qpayState = const AsyncLoading();
      _loaded = true;
      _notifyIfCurrent(generation);
    }

    final results = await Future.wait<Object?>([
      repo.getOrderDetail(orderId),
      repo.getPayments(orderId),
      repo.getQPay(orderId),
    ]);
    if (!_isCurrent(generation)) return;

    final detail = results[0] as Result<ServiceOrderDetail>;
    final ledger = results[1] as Result<List<OrderPaymentRecord>>;
    final qpayResult =
        results[2] as Result<({bool qpayEnabled, OrderPayment? pending})>;
    detailState = switch (detail) {
      Ok(:final value) => AsyncData(value),
      Err(:final error) => AsyncError(error),
    };
    paymentsState = switch (ledger) {
      Ok(:final value) => AsyncData(value),
      Err(:final error) => AsyncError(error),
    };
    qpayState = switch (qpayResult) {
      Ok(:final value) => AsyncData(
        QPayState(qpayEnabled: value.qpayEnabled, pending: value.pending),
      ),
      Err(:final error) => AsyncError(error),
    };
    lastError = _firstError(detail, ledger, qpayResult);
    _notifyIfCurrent(generation);
  }

  /// Creates a paid ledger row. The server remains authoritative for the
  /// final status and balance; this method only performs local shape checks.
  Future<bool> createManual({
    required String amount,
    required OrderPaymentMethod method,
  }) async {
    if (!canCreate || method == OrderPaymentMethod.QPAY) return false;
    final normalized = _validateAmount(amount);
    if (normalized == null) {
      _setError(
        const AppError(
          ErrorKind.unknown,
          'Дүнг 0-ээс их, 2 орны бутархайтай оруулна уу.',
        ),
      );
      return false;
    }
    final remaining = _remainingMoney;
    if (remaining != null && _compareDecimal(normalized, remaining.raw) > 0) {
      _setError(
        const AppError(ErrorKind.unknown, 'Төлбөрийн дүн үлдэгдлээс их байна.'),
      );
      return false;
    }
    return _runMutation(() async {
      final result = await repo.createPayment(
        orderId,
        method: method,
        amount: Money(normalized),
      );
      return switch (result) {
        Ok() => true,
        Err(:final error) => _failed(error),
      };
    });
  }

  Future<bool> reverse(OrderPaymentRecord payment) async {
    if (!canDelete || payment.status != OrderPaymentRecordStatus.PAID) {
      return false;
    }
    return _runMutation(() async {
      final result = await repo.reversePayment(orderId, payment.id);
      return switch (result) {
        Ok() => true,
        Err(:final error) => _failed(error),
      };
    });
  }

  Future<bool> createQPay() async {
    if (!canCreate || qpay?.qpayEnabled != true || qpay?.pending != null) {
      return false;
    }
    _clearQPayFeedback();
    return _runMutation(() async {
      final result = await repo.createQPay(orderId);
      return switch (result) {
        Ok() => true,
        Err(:final error) => _failed(error),
      };
    });
  }

  Future<bool> checkQPay() async {
    final pending = qpay?.pending;
    if (!canEdit || pending == null) return false;
    _clearQPayFeedback();
    return _runMutation(() async {
      final result = await repo.checkQPay(orderId, pending.id);
      return switch (result) {
        Ok(:final value) => _recordQPayCheck(value),
        Err(:final error) => _failedQPay(error),
      };
    });
  }

  Future<bool> cancelQPay() async {
    final pending = qpay?.pending;
    if (!canDelete || pending == null) return false;
    _clearQPayFeedback();
    return _runMutation(() async {
      final result = await repo.cancelQPay(orderId, pending.id);
      return switch (result) {
        Ok() => true,
        Err(:final error) => _failed(error),
      };
    });
  }

  Money? get _remainingMoney {
    final value = order;
    if (value == null) return null;
    if (value.paymentTotals != null) {
      return value.paymentTotals!.remainingAmountMoney;
    }
    final total = value.totalAmountMoney;
    final paid = value.paidAmountMoney ?? _ledgerPaidMoney;
    if (total == null || paid == null) return null;
    return Money(_subtractDecimal(total.raw, paid.raw));
  }

  Money? get _ledgerPaidMoney {
    if (paymentsState is AsyncError) return null;
    final paid = payments
        .where((item) => item.status == OrderPaymentRecordStatus.PAID)
        .map((item) => item.amountMoney.raw)
        .toList(growable: false);
    if (paid.isEmpty) return const Money('0');
    var sum = paid.first;
    for (final value in paid.skip(1)) {
      sum = _addDecimal(sum, value);
    }
    return Money(sum);
  }

  bool _failed(AppError error) {
    _setError(error);
    return false;
  }

  bool _recordQPayCheck(({bool paid, String? message}) value) {
    qpayCheckError = null;
    qpayCheckResult = QPayCheckResult(
      paid: value.paid,
      message: value.message?.trim().isEmpty == true ? null : value.message,
    );
    notifyListeners();
    return value.paid;
  }

  bool _failedQPay(AppError error) {
    qpayCheckResult = null;
    qpayCheckError = error;
    return _failed(error);
  }

  void _clearQPayFeedback() {
    if (qpayCheckResult == null && qpayCheckError == null) return;
    qpayCheckResult = null;
    qpayCheckError = null;
    notifyListeners();
  }

  Future<bool> _runMutation(Future<bool> Function() operation) async {
    if (_disposed || _operationActive) return false;
    _operationActive = true;
    lastError = null;
    notifyListeners();
    var succeeded = false;
    try {
      succeeded = await operation();
      if (!_disposed) {
        // A rejected or racing server mutation still invalidates the three
        // snapshots on screen. Preserve its error after the authoritative
        // reload so the user sees the useful server response.
        final mutationError = lastError;
        await refresh();
        if (mutationError != null && !_disposed) {
          lastError = mutationError;
          notifyListeners();
        }
      }
      return succeeded;
    } finally {
      if (!_disposed) {
        _operationActive = false;
        notifyListeners();
      }
    }
  }

  void _setError(AppError error) {
    if (_disposed) return;
    lastError = error;
    notifyListeners();
  }

  AppError? _firstError(
    Result<ServiceOrderDetail> detail,
    Result<List<OrderPaymentRecord>> ledger,
    Result<({bool qpayEnabled, OrderPayment? pending})> qpayResult,
  ) {
    if (detail case Err(:final error)) return error;
    if (ledger case Err(:final error)) return error;
    if (qpayResult case Err(:final error)) return error;
    return null;
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _notifyIfCurrent(int generation) {
    if (_isCurrent(generation)) notifyListeners();
  }

  String? _validateAmount(String input) {
    final value = input.trim();
    if (!RegExp(r'^(?:0|[1-9]\d*)(?:\.\d{1,2})?$').hasMatch(value)) {
      return null;
    }
    if (_compareDecimal(value, '0') <= 0) return null;
    return value;
  }

  int _compareDecimal(String left, String right) {
    final a = _decimalParts(left);
    final b = _decimalParts(right);
    final scale = a.$2.length > b.$2.length ? a.$2.length : b.$2.length;
    final av =
        BigInt.parse(a.$1) * BigInt.from(10).pow(scale) +
        _fraction(a.$2, scale);
    final bv =
        BigInt.parse(b.$1) * BigInt.from(10).pow(scale) +
        _fraction(b.$2, scale);
    return av.compareTo(bv);
  }

  String _subtractDecimal(String left, String right) {
    final a = _decimalParts(left);
    final b = _decimalParts(right);
    final scale = a.$2.length > b.$2.length ? a.$2.length : b.$2.length;
    final av =
        BigInt.parse(a.$1) * BigInt.from(10).pow(scale) +
        _fraction(a.$2, scale);
    final bv =
        BigInt.parse(b.$1) * BigInt.from(10).pow(scale) +
        _fraction(b.$2, scale);
    final result = av - bv;
    if (result <= BigInt.zero) return '0';
    final raw = result.toString().padLeft(scale + 1, '0');
    if (scale == 0) return raw;
    final split = raw.length - scale;
    return '${raw.substring(0, split)}.${raw.substring(split)}'.replaceFirst(
      RegExp(r'\.0+$'),
      '',
    );
  }

  String _addDecimal(String left, String right) {
    final a = _decimalParts(left);
    final b = _decimalParts(right);
    final scale = a.$2.length > b.$2.length ? a.$2.length : b.$2.length;
    final av =
        BigInt.parse(a.$1) * BigInt.from(10).pow(scale) +
        _fraction(a.$2, scale);
    final bv =
        BigInt.parse(b.$1) * BigInt.from(10).pow(scale) +
        _fraction(b.$2, scale);
    final raw = (av + bv).toString().padLeft(scale + 1, '0');
    if (scale == 0) return raw;
    final split = raw.length - scale;
    return '${raw.substring(0, split)}.${raw.substring(split)}';
  }

  // scale == 0 үед бутархай хэсэг хоосон — BigInt.parse('') FormatException
  // шиддэг тул бүхэл дүн (жишээ нь "14000") бүртгэх товч чимээгүй унаж байсан.
  BigInt _fraction(String digits, int scale) {
    final padded = digits.padRight(scale, '0');
    return padded.isEmpty ? BigInt.zero : BigInt.parse(padded);
  }

  (String, String) _decimalParts(String value) {
    final pieces = value.split('.');
    return (pieces.first, pieces.length == 1 ? '' : pieces.last);
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
