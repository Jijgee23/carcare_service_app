import 'package:carcare_service/features/notifications/data/notification_dto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _item({Map<String, dynamic>? extra}) => {
  'id': ' n-1 ',
  'type': ' order_completed ',
  'title': ' Гарчиг ',
  'body': ' Бие ',
  'data': {'orderId': 'o-1'},
  'readAt': '',
  'createdAt': '2026-01-02T03:04:05Z',
  ...?extra,
};

Map<String, dynamic> _page({Object? item = const _Sentinel()}) => {
  'notifications': [item is _Sentinel ? _item() : item],
  'pagination': {
    'page': 1,
    'pageSize': 20,
    'total': 1,
    'totalPages': 1,
    'hasPrev': false,
    'hasNext': false,
  },
  'unreadCount': 1,
};

class _Sentinel {
  const _Sentinel();
}

void main() {
  test('trims fields, accepts additive fields, and maps optional blanks', () {
    final dto = NotificationDto.fromJson(
      _item(extra: {'newServerField': true}),
    );

    expect(dto.id, 'n-1');
    expect(dto.type, 'order_completed');
    expect(dto.title, 'Гарчиг');
    expect(dto.body, 'Бие');
    expect(dto.readAt, isNull);
    expect(dto.toDomain().data['orderId'], 'o-1');
  });

  test('missing required fields fail defensively', () {
    for (final field in ['id', 'type', 'title', 'body', 'createdAt']) {
      final json = _item()..remove(field);
      expect(
        () => NotificationDto.fromJson(json),
        throwsA(isA<NotificationParseException>()),
        reason: field,
      );
    }
  });

  test('page parser validates the response envelope', () {
    final page = NotificationPageDto.fromJson(_page());
    expect(page.toDomain().items, hasLength(1));
    expect(
      () => NotificationPageDto.fromJson({'notifications': 'bad'}),
      throwsA(isA<NotificationParseException>()),
    );
  });
}
