import 'package:flutter/foundation.dart';

import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/profile/data/account_repository.dart';
import 'package:carcare_service/features/profile/domain/account_repository.dart';

/// Edit-profile form submission — P8-F2.
///
/// `PATCH /api/v1/me` is a whole-record replace (see
/// [AccountRepository.updateProfile]'s doc comment): [submit] always sends
/// all four fields explicitly. On success the repository has already merged
/// the returned payload into the stored Hive [User] and persisted it via
/// `Authenticator.user =` — this controller does not repeat that, it only
/// forwards the [Result] so the screen can show inline field errors or call
/// its `onSaved` callback.
class EditProfileController extends ChangeNotifier {
  EditProfileController({AccountRepository? repo})
    : _repo = repo ?? RemoteAccountRepository();

  final AccountRepository _repo;
  bool submitting = false;

  Future<Result<User>> submit({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
  }) async {
    submitting = true;
    notifyListeners();
    final result = await _repo.updateProfile(
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
    );
    submitting = false;
    notifyListeners();
    return result;
  }
}
