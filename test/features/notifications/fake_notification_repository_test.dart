import 'package:carcare_service/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_notification_repository.dart';

void main() {
  test(
    'getList returns the seeded notifications with mixed read state',
    () async {
      final repo = FakeNotificationRepository();

      final result = await repo.getList();

      final page = (result as Ok).value;
      expect(page.items, hasLength(3));
      expect(page.unreadCount, 2);
    },
  );

  test('markRead flips a single notification to read', () async {
    final repo = FakeNotificationRepository();

    await repo.markRead('n-1');

    final page = (await repo.getList() as Ok).value;
    expect(page.items.firstWhere((n) => n.id == 'n-1').isUnread, isFalse);
    expect(page.unreadCount, 1);
  });

  test('markAllRead flips every notification to read', () async {
    final repo = FakeNotificationRepository();

    await repo.markAllRead();

    final page = (await repo.getList() as Ok).value;
    expect(page.unreadCount, 0);
  });
}
