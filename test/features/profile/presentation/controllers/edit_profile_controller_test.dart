import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/profile/presentation/controllers/edit_profile_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../features/profile/data/fake_account_repository.dart';

void main() {
  group('EditProfileController', () {
    test('submit sends all four fields and returns the updated user', () async {
      final repo = FakeAccountRepository();
      final c = EditProfileController(repo: repo);
      final result = await c.submit(
        firstName: 'Оюунаа',
        lastName: 'Батаа',
        email: 'oyunaa@example.test',
        phone: '99112233',
      );
      expect(result, isA<Ok<Object?>>());
      final user = (result as Ok).value;
      expect(user.firstName, 'Оюунаа');
      expect(user.lastName, 'Батаа');
      expect(user.email, 'oyunaa@example.test');
      expect(user.phone, '99112233');
      expect(c.submitting, isFalse);
    });

    test('submit surfaces server fieldErrors', () async {
      final repo = FakeAccountRepository();
      final c = EditProfileController(repo: repo);
      final result = await c.submit(
        firstName: '',
        lastName: 'Батаа',
        email: 'oyunaa@example.test',
        phone: '99112233',
      );
      final err = (result as Err).error;
      expect(err.fieldErrors, containsPair('firstName', isNotEmpty));
    });

    test('submit surfaces a generic/network failure', () async {
      final repo = FakeAccountRepository();
      repo.failNext = const AppError(ErrorKind.network, 'no connection');
      final c = EditProfileController(repo: repo);
      final result = await c.submit(
        firstName: 'A',
        lastName: 'B',
        email: 'a@b.test',
        phone: '99112233',
      );
      expect(result, isA<Err<Object?>>());
      expect((result as Err).error.kind, ErrorKind.network);
    });

    test('submitting flips true then false around the call', () async {
      final repo = FakeAccountRepository();
      final c = EditProfileController(repo: repo);
      final future = c.submit(
        firstName: 'A',
        lastName: 'B',
        email: 'a@b.test',
        phone: '99112233',
      );
      expect(c.submitting, isTrue);
      await future;
      expect(c.submitting, isFalse);
    });
  });
}
