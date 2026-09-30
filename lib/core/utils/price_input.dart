import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Price fields with thousands separators ("25,000"), ported from the web's
/// `liveFormatPriceInput` / `formatPriceInput` (`carservice.mn/lib/orders.ts`).

final _grouped = NumberFormat('#,##0.##', 'en_US');

/// While typing: digits grouped by thousands, at most one dot and two
/// decimals; a trailing dot ("540.") stays until [formatPriceInput] tidies it.
String liveFormatPriceInput(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[^\d.]'), '');
  String groupInt(String digits) => digits
      .replaceFirst(RegExp(r'^0+(?=\d)'), '')
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  final dot = cleaned.indexOf('.');
  if (dot == -1) return groupInt(cleaned);
  final decimals = cleaned.substring(dot + 1).replaceAll('.', '');
  return '${groupInt(cleaned.substring(0, dot))}.'
      '${decimals.length > 2 ? decimals.substring(0, 2) : decimals}';
}

/// The settled form, e.g. on load: "12000" → "12,000", "540." → "540".
String formatPriceInput(String value) {
  final n = parsePriceInput(value);
  return n == null ? value : _grouped.format(n);
}

/// The number in a price field, separators ignored; null when empty or not
/// a number.
num? parsePriceInput(String value) =>
    num.tryParse(value.replaceAll(',', '').trim());

/// [liveFormatPriceInput] as the field is edited, keeping the cursor at the
/// same distance from the end.
class PriceInputFormatter extends TextInputFormatter {
  const PriceInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = liveFormatPriceInput(newValue.text);
    final fromEnd = newValue.text.length - newValue.selection.extentOffset;
    final offset = (text.length - fromEnd).clamp(0, text.length);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
