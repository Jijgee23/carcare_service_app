import 'package:flutter/services.dart';

/// Талбарт бичсэн текстийг том үсэг болгоно (улсын дугаар, VIN).
class UpperCaseTextFormatter extends TextInputFormatter {
  const UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}

/// Гүйлтийн (км) оргил оронгийн хязгаар — `int.tryParse` чимээгүй алдахаас сэргийлнэ.
const int kMileageMaxDigits = 7;
