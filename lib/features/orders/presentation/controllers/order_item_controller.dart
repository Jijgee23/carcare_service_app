import 'package:flutter/foundation.dart';

import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/async_value.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/orders/domain/order.dart';
import 'package:carcare_service/features/orders/domain/orders_repository.dart';
import 'package:carcare_service/features/orders/presentation/controllers/order_detail_controller.dart';
import 'package:carcare_service/features/orders/presentation/controllers/order_list_controller.dart';

class ItemMoneyValidation {
  const ItemMoneyValidation._(this.value, this.error);

  final Money? value;
  final String? error;

  bool get isValid => value != null;

  static ItemMoneyValidation quantity(String input) => _parse(
    input,
    maxScale: 3,
    maximum: BigInt.from(1000000),
    minimumExclusive: true,
    label: 'Тоо',
  );

  static ItemMoneyValidation price(String input) => _parse(
    input,
    maxScale: 2,
    maximum: BigInt.from(1000000000),
    minimumExclusive: false,
    label: 'Нэгж үнэ',
  );

  static ItemMoneyValidation _parse(
    String input, {
    required int maxScale,
    required BigInt maximum,
    required bool minimumExclusive,
    required String label,
  }) {
    final raw = input.trim().replaceAll(',', '');
    if (!RegExp(r'^(?:0|[1-9]\d*)(?:\.\d+)?$').hasMatch(raw)) {
      return ItemMoneyValidation._(
        null,
        '$label нь зөв аравтын тоо байх ёстой.',
      );
    }
    final parts = raw.split('.');
    final fraction = parts.length == 1 ? '' : parts[1];
    if (fraction.length > maxScale) {
      return ItemMoneyValidation._(
        null,
        '$label нь таслалаас хойш $maxScale оронтой байна.',
      );
    }
    final scale = fraction.length;
    final multiplier = BigInt.from(10).pow(scale);
    final integer =
        BigInt.parse(parts[0]) * multiplier +
        BigInt.parse(fraction.isEmpty ? '0' : fraction);
    final max = maximum * multiplier;
    if (integer > max || (minimumExclusive && integer == BigInt.zero)) {
      return ItemMoneyValidation._(
        null,
        minimumExclusive
            ? '$label нь 0-ээс их, 1,000,000-аас ихгүй байна.'
            : '$label нь 0-ээс багагүй, 1,000,000,000-аас ихгүй байна.',
      );
    }
    return ItemMoneyValidation._(Money(raw), null);
  }
}

/// Owns item mutations for one order. The server remains the only source of
/// truth: this controller never patches an item into a local detail snapshot.
/// Every completed request, including a failed request, is followed by a
/// detail/list reload so concurrent web changes and validation failures cannot
/// leave stale item state on screen.
class OrderItemController extends ChangeNotifier {
  OrderItemController({
    required this.repo,
    required this.orderId,
    required this.detailController,
    this.listController,
  });

  final OrdersRepository repo;
  final String orderId;
  final OrderDetailController detailController;
  final OrderListController? listController;

  AsyncValue<OrderItemHistoryPage> historyState = const AsyncLoading();
  int historyPage = 0;
  bool historyHasNext = false;
  String? historyNextError;
  int _generation = 0;
  bool _disposed = false;
  final Set<String> _inFlight = <String>{};
  Future<Result<OrderItemHistoryPage>>? _nextHistoryRequest;

  bool get isLoadingHistory => historyState is AsyncLoading;
  bool get isLoadingNextHistory => _nextHistoryRequest != null;

  Future<Result<ServiceItem>> add({
    required ItemKind kind,
    required String description,
    required Money quantity,
    required Money unitPrice,
    String? serviceId,
    String? diagnosticTemplateId,
  }) => _runItem(
    'add',
    () => repo.addItemMoney(
      orderId,
      kind: kind,
      description: description,
      quantity: quantity,
      unitPrice: unitPrice,
      serviceId: serviceId,
      diagnosticTemplateId: diagnosticTemplateId,
    ),
  );

  Future<Result<ServiceItem>> edit({
    required String itemId,
    ItemKind? kind,
    String? description,
    Money? quantity,
    Money? unitPrice,
  }) => _runItem(
    'edit:$itemId',
    () => repo.updateItemMoney(
      orderId,
      itemId,
      kind: kind,
      description: description,
      quantity: quantity,
      unitPrice: unitPrice,
    ),
  );

  Future<Result<ServiceItem>> changePrice(String itemId, Money unitPrice) =>
      _runItem(
        'price:$itemId',
        () => repo.changeItemPrice(orderId, itemId, unitPrice),
      );

  Future<Result<ServiceItem>> changeStatus(
    String itemId,
    ServiceItemStatus status,
  ) => _runItem(
    'status:$itemId:${status.name}',
    () => repo.changeItemStatus(orderId, itemId, status),
  );

  Future<Result<void>> cancel(String itemId) =>
      _runVoid('cancel:$itemId', () => repo.cancelItem(orderId, itemId));

  Future<Result<OrderItemHistoryPage>> loadHistory({
    int page = 1,
    int pageSize = 20,
  }) async {
    if (_disposed) return _disposedError<OrderItemHistoryPage>();
    final generation = ++_generation;
    historyState = const AsyncLoading();
    historyNextError = null;
    notifyListeners();
    final result = await repo.getItemHistory(
      orderId,
      page: page,
      pageSize: pageSize,
    );
    if (_disposed || generation != _generation) return result;
    historyState = switch (result) {
      Ok(:final value) => AsyncData(value),
      Err(:final error) => AsyncError(error),
    };
    if (result case Ok(:final value)) {
      historyPage = value.pagination.page;
      historyHasNext = value.pagination.hasNext;
    } else {
      historyPage = page;
      historyHasNext = false;
    }
    notifyListeners();
    return result;
  }

  Future<Result<OrderItemHistoryPage>> loadNextHistory() async {
    final pending = _nextHistoryRequest;
    if (pending != null) return pending;
    if (!historyHasNext || historyState is! AsyncData<OrderItemHistoryPage>) {
      return historyState is AsyncData<OrderItemHistoryPage>
          ? Ok((historyState as AsyncData<OrderItemHistoryPage>).value)
          : _disposedError<OrderItemHistoryPage>();
    }
    final request = _loadNextHistoryPage();
    _nextHistoryRequest = request;
    try {
      return await request;
    } finally {
      if (identical(_nextHistoryRequest, request)) {
        _nextHistoryRequest = null;
      }
    }
  }

  Future<Result<OrderItemHistoryPage>> _loadNextHistoryPage() async {
    final generation = ++_generation;
    final current = (historyState as AsyncData<OrderItemHistoryPage>).value;
    final result = await repo.getItemHistory(
      orderId,
      page: historyPage + 1,
      pageSize: current.pagination.pageSize,
    );
    if (_disposed || generation != _generation) return result;
    switch (result) {
      case Ok(:final value):
        final combined = OrderItemHistoryPage(
          items: [...current.items, ...value.items],
          pagination: value.pagination,
        );
        historyState = AsyncData(combined);
        historyPage = value.pagination.page;
        historyHasNext = value.pagination.hasNext;
        historyNextError = null;
      case Err(:final error):
        // Keep the accumulated page visible. The sheet renders this message
        // beside a retry action instead of replacing it with AsyncError.
        historyNextError = error.display;
    }
    notifyListeners();
    return result;
  }

  Future<Result<T>> _runItem<T>(
    String key,
    Future<Result<T>> Function() action,
  ) async {
    if (_disposed) return _disposedError<T>();
    if (!_inFlight.add(key)) {
      return const Err(
        AppError(ErrorKind.unknown, 'Энэ үйлдэл аль хэдийн хийгдэж байна.'),
      );
    }
    final generation = _generation;
    try {
      late final Result<T> result;
      try {
        result = await action();
      } catch (error) {
        result = Err(
          error is AppError
              ? error
              : const AppError(ErrorKind.unknown, 'Мөрийн үйлдэл амжилтгүй.'),
        );
      }
      await _reloadAuthoritative(generation);
      return result;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<Result<void>> _runVoid(
    String key,
    Future<Result<void>> Function() action,
  ) async {
    if (_disposed) return _disposedError<void>();
    if (!_inFlight.add(key)) {
      return const Err(
        AppError(ErrorKind.unknown, 'Энэ үйлдэл аль хэдийн хийгдэж байна.'),
      );
    }
    final generation = _generation;
    try {
      late final Result<void> result;
      try {
        result = await action();
      } catch (error) {
        result = Err(
          error is AppError
              ? error
              : const AppError(ErrorKind.unknown, 'Мөрийн үйлдэл амжилтгүй.'),
        );
      }
      await _reloadAuthoritative(generation);
      return result;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<void> _reloadAuthoritative(int generation) async {
    if (_disposed || generation != _generation) return;
    await detailController.refresh();
    if (_disposed || generation != _generation) return;
    await listController?.refresh();
  }

  Err<T> _disposedError<T>() =>
      const Err(AppError(ErrorKind.unknown, 'Энэ дэлгэц хаагдсан байна.'));

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _inFlight.clear();
    super.dispose();
  }
}
