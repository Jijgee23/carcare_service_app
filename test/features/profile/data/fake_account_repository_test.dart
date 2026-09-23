import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/profile/domain/account_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_account_repository.dart';

void main() {
  test('updateProfile updates the in-memory user and preserves tokens', () async {
    final repo = FakeAccountRepository();
    final before = repo.user;
    final result = await repo.updateProfile(
      firstName: 'Шинэ',
      lastName: 'Нэр',
      email: 'new@b.mn',
      phone: '99009900',
    );
    final updated = (result as Ok).value;
    expect(updated.email, 'new@b.mn');
    expect(updated.accessToken, before.accessToken);
    expect(repo.user.email, 'new@b.mn');
  });

  test('updateProfile rejects a blank firstName as VALIDATION', () async {
    final repo = FakeAccountRepository();
    final result = await repo.updateProfile(
      firstName: '',
      lastName: 'Нэр',
      email: 'new@b.mn',
      phone: '99009900',
    );
    expect((result as Err).error.code, 'VALIDATION');
  });

  test('changePassword rejects the wrong current password', () async {
    final repo = FakeAccountRepository();
    final result = await repo.changePassword(
      currentPassword: 'wrong',
      newPassword: 'new-password',
      confirmPassword: 'new-password',
    );
    expect((result as Err).error.fieldErrors, contains('currentPassword'));
  });

  test('changePassword succeeds with the fixed correct password', () async {
    final repo = FakeAccountRepository();
    final result = await repo.changePassword(
      currentPassword: 'correct-password',
      newPassword: 'new-password-1',
      confirmPassword: 'new-password-1',
    );
    expect(result, isA<Ok>());
  });

  test('getSessions splits active vs ended and counts other-active', () async {
    final repo = FakeAccountRepository();
    final result = await repo.getSessions();
    final page = (result as Ok).value;
    expect(page.active, hasLength(1));
    expect(page.active.single.current, isTrue);
    expect(page.otherActiveCount, 0);
  });

  test('revokeSession on the current session echoes loggedOut: true', () async {
    final repo = FakeAccountRepository();
    final result = await repo.revokeSession(
      's-1',
      source: AccountSessionSource.mobile,
      isCurrent: true,
    );
    expect((result as Ok).value.loggedOut, isTrue);
    final page = (await repo.getSessions() as Ok).value;
    expect(page.active, isEmpty);
  });

  test('revokeSession on an unknown id is NOT_FOUND', () async {
    final repo = FakeAccountRepository();
    final result = await repo.revokeSession('missing', source: AccountSessionSource.web);
    expect((result as Err).error.code, 'NOT_FOUND');
  });

  test('failNext forces the next call to error, then clears itself', () async {
    final repo = FakeAccountRepository()
      ..failNext = const AppError(
        ErrorKind.unknown,
        'Хэт олон удаа буруу оролдсон.',
        statusCode: 429,
        code: 'RATE_LIMITED',
      );
    final first = await repo.changePassword(
      currentPassword: 'correct-password',
      newPassword: 'new-password-1',
      confirmPassword: 'new-password-1',
    );
    expect((first as Err).error.code, 'RATE_LIMITED');

    final second = await repo.changePassword(
      currentPassword: 'correct-password',
      newPassword: 'new-password-1',
      confirmPassword: 'new-password-1',
    );
    expect(second, isA<Ok>());
  });
}
