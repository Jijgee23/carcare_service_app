import 'package:carservice_business/core/utils/validators.dart';
import 'package:carservice_business/core/utils/vehicle_plate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isNoPlate matches the sentinel case-insensitively', () {
    expect(isNoPlate('ДУГААРГҮЙ'), isTrue);
    expect(isNoPlate(' дугааргүй '), isTrue);
    expect(isNoPlate('1234ҮНА'), isFalse);
    expect(isNoPlate(null), isFalse);
  });

  test('plateLabel mirrors backend label logic', () {
    expect(plateLabel('1234ҮНА', 'X'), '1234ҮНА');
    expect(
      plateLabel(kNoPlate, 'JT123456789012345'),
      'Дугааргүй · JT123456789012345',
    );
    expect(plateLabel(kNoPlate), 'Дугааргүй');
  });

  test('isValidVin matches backend rules', () {
    expect(isValidVin('JTDKN3DU0A0123456'), isTrue);
    expect(isValidVin('JTDKN3DU0A012345I'), isFalse); // I not allowed in 17
    expect(isValidVin('ZVW30-1234567'), isTrue);
    expect(isValidVin('ZVW30-12-34'), isFalse);
    expect(isValidVin('ABC12'), isFalse);
  });

  test(
    'plate validator accepts the sentinel; vin validator honours required',
    () {
      expect(AppValidators.plate(kNoPlate), isNull);
      expect(AppValidators.vin(required: true)(''), isNotNull);
      expect(AppValidators.vin()(''), isNull);
    },
  );
}
