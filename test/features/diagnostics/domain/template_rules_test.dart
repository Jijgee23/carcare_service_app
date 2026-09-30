import 'package:carservice_business/core/utils/price_input.dart';
import 'package:carservice_business/features/diagnostics/domain/diagnostic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('check answers are toned by their wording, like the web', () {
    expect(checkOptionTone('Хэвийн'), CheckStatus.good);
    expect(checkOptionTone('OK'), CheckStatus.good);
    expect(checkOptionTone('Анхаарах'), CheckStatus.warning);
    expect(checkOptionTone('Элэгдсэн'), CheckStatus.warning);
    expect(checkOptionTone('Дунд зэрэг'), CheckStatus.warning);
    expect(checkOptionTone('Солих'), CheckStatus.danger);
    expect(checkOptionTone('Засах'), CheckStatus.danger);
    expect(checkOptionTone('Муу'), CheckStatus.danger);
  });

  test('a question with showWhen shows once its source is answered with '
      'one of the values', () {
    const item = TemplateItem(
      id: 'note',
      label: 'Тайлбар',
      type: ItemType.text,
      required: false,
      showWhen: ShowWhen(itemId: 'state', values: ['Солих', 'Анхаарах']),
    );
    expect(item.isVisible(const {}), isFalse);
    expect(item.isVisible(const {'state': 'Хэвийн'}), isFalse);
    expect(item.isVisible(const {'state': 'Солих'}), isTrue);
    expect(item.isVisible(const {'state': ''}), isFalse);

    const free = TemplateItem(
      id: 'a',
      label: 'A',
      type: ItemType.text,
      required: false,
    );
    expect(free.isVisible(const {}), isTrue);
  });

  test('a check question without options falls back to the server default', () {
    const item = TemplateItem(
      id: 'a',
      label: 'A',
      type: ItemType.check,
      required: false,
    );
    expect(item.effectiveOptions, ['Хэвийн', 'Анхаарах', 'Солих']);
  });

  group('price input', () {
    test('groups thousands while typing, like liveFormatPriceInput', () {
      expect(liveFormatPriceInput('25000'), '25,000');
      expect(liveFormatPriceInput('1234567'), '1,234,567');
      expect(liveFormatPriceInput('0012'), '12');
      expect(liveFormatPriceInput('a1b2'), '12');
      expect(liveFormatPriceInput('540.'), '540.');
      expect(liveFormatPriceInput('1.2345'), '1.23');
      expect(liveFormatPriceInput('1.2.3'), '1.23');
      expect(liveFormatPriceInput(''), '');
    });

    test('settles and parses, like formatPriceInput', () {
      expect(formatPriceInput('12000.0'), '12,000');
      expect(formatPriceInput('540.'), '540');
      expect(formatPriceInput('1250.5'), '1,250.5');
      expect(formatPriceInput(''), '');
      expect(parsePriceInput('25,000'), 25000);
      expect(parsePriceInput(' '), isNull);
      expect(parsePriceInput('abc'), isNull);
    });
  });
}
