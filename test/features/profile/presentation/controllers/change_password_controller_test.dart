import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/profile/presentation/controllers/change_password_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../features/profile/data/fake_account_repository.dart';

void main() {
  group('ChangePasswordController.validate', () {
    test('empty current password is flagged', () {
      final errors = ChangePasswordController.validate(
        currentPassword: '',
        newPassword: 'newpassword1',
        confirmPassword: 'newpassword1',
      );
      expect(errors['currentPassword'], 'Одоогийн нууц үгээ оруулна уу.');
    });

    test('short new password is flagged', () {
      final errors = ChangePasswordController.validate(
        currentPassword: 'correct-password',
        newPassword: 'short',
        confirmPassword: 'short',
      );
      expect(errors['newPassword'], 'Шинэ нууц үг 8+ тэмдэгт байна.');
    });

    test('mismatched confirm is flagged', () {
      final errors = ChangePasswordController.validate(
        currentPassword: 'correct-password',
        newPassword: 'newpassword1',
        confirmPassword: 'newpassword2',
      );
      expect(errors['confirmPassword'], 'Нууц үг таарахгүй байна.');
    });

    test('valid input has no errors', () {
      final errors = ChangePasswordController.validate(
        currentPassword: 'correct-password',
        newPassword: 'newpassword1',
        confirmPassword: 'newpassword1',
      );
      expect(errors, isEmpty);
    });
  });

  group('ChangePasswordController.submit', () {
    test('successful submit returns Ok', () async {
      final repo = FakeAccountRepository();
      final c = ChangePasswordController(repo: repo);
      final result = await c.submit(
        currentPassword: 'correct-password',
        newPassword: 'newpassword1',
        confirmPassword: 'newpassword1',
      );
      expect(result, isA<Ok<Object?>>());
      expect(c.submitting, isFalse);
    });

    test('server fieldErrors are surfaced (wrong current password)', () async {
      final repo = FakeAccountRepository();
      final c = ChangePasswordController(repo: repo);
      final result = await c.submit(
        currentPassword: 'wrong-password',
        newPassword: 'newpassword1',
        confirmPassword: 'newpassword1',
      );
      final err = (result as Err).error;
      expect(err.fieldErrors, containsPair('currentPassword', isNotEmpty));
    });

    test('RATE_LIMITED error is surfaced distinctly', () async {
      final repo = FakeAccountRepository();
      repo.failNext = const AppError(
        ErrorKind.unknown,
        'Хэт олон удаа буруу оролдсон тул түр хугацаагаар хориглогдлоо.',
        statusCode: 429,
        code: 'RATE_LIMITED',
      );
      final c = ChangePasswordController(repo: repo);
      final result = await c.submit(
        currentPassword: 'correct-password',
        newPassword: 'newpassword1',
        confirmPassword: 'newpassword1',
      );
      final err = (result as Err).error;
      expect(err.code, 'RATE_LIMITED');
      expect(err.statusCode, 429);
    });

    test('generic/network failure is surfaced', () async {
      final repo = FakeAccountRepository();
      repo.failNext = const AppError(ErrorKind.network, 'no connection');
      final c = ChangePasswordController(repo: repo);
      final result = await c.submit(
        currentPassword: 'correct-password',
        newPassword: 'newpassword1',
        confirmPassword: 'newpassword1',
      );
      expect((result as Err).error.kind, ErrorKind.network);
    });
  });
}
