import 'package:carcare_service/core/errors/app_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('two-argument construction remains source-compatible', () {
    const error = AppError(ErrorKind.unknown, 'failed');

    expect(error.statusCode, isNull);
    expect(error.code, isNull);
    expect(error.fieldErrors, isNull);
    expect(error.display, 'failed');
  });

  test('preserves optional transport metadata and display semantics', () {
    const error = AppError(
      ErrorKind.forbidden,
      'forbidden',
      statusCode: 403,
      code: 'WORKING_BRANCH_STALE',
      fieldErrors: {'branchId': 'Select another branch'},
    );

    expect(error.statusCode, 403);
    expect(error.code, 'WORKING_BRANCH_STALE');
    expect(error.fieldErrors, {'branchId': 'Select another branch'});
    expect(error.display, 'forbidden');
  });
}
