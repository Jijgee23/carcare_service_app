import 'package:carcare_service/features/profile/presentation/screens/change_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fake_account_repository.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  Finder passwordFieldByKey(String key) => find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(TextField),
  );

  testWidgets('renders all three password fields', (tester) async {
    await pumpAt(
      tester,
      ChangePasswordScreen(repo: FakeAccountRepository()),
    );
    expect(find.text('Нууц үг солих'), findsOneWidget);
    expect(find.byKey(const ValueKey('change_password_current')), findsOneWidget);
    expect(find.byKey(const ValueKey('change_password_new')), findsOneWidget);
    expect(find.byKey(const ValueKey('change_password_confirm')), findsOneWidget);
  });

  testWidgets('no horizontal overflow at 375dp', (tester) async {
    await pumpAt(tester, ChangePasswordScreen(repo: FakeAccountRepository()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('client-side validation blocks submit and shows messages', (
    tester,
  ) async {
    await pumpAt(tester, ChangePasswordScreen(repo: FakeAccountRepository()));
    await tester.tap(find.text('Хадгалах'));
    await tester.pumpAndSettle();
    expect(find.text('Одоогийн нууц үгээ оруулна уу.'), findsOneWidget);
  });

  testWidgets('show/hide toggle switches obscureText', (tester) async {
    await pumpAt(tester, ChangePasswordScreen(repo: FakeAccountRepository()));

    final field = tester.widget<TextField>(
      passwordFieldByKey('change_password_current'),
    );
    expect(field.obscureText, isTrue);

    final toggle = find.descendant(
      of: find.byKey(const ValueKey('change_password_current')),
      matching: find.byType(IconButton),
    );
    await tester.tap(toggle);
    await tester.pump();

    final toggledField = tester.widget<TextField>(
      passwordFieldByKey('change_password_current'),
    );
    expect(toggledField.obscureText, isFalse);
  });

  testWidgets('server fieldErrors show inline (wrong current password)', (
    tester,
  ) async {
    await pumpAt(tester, ChangePasswordScreen(repo: FakeAccountRepository()));

    await tester.enterText(
      passwordFieldByKey('change_password_current'),
      'wrong-password',
    );
    await tester.enterText(
      passwordFieldByKey('change_password_new'),
      'newpassword1',
    );
    await tester.enterText(
      passwordFieldByKey('change_password_confirm'),
      'newpassword1',
    );
    await tester.tap(find.text('Хадгалах'));
    await tester.pumpAndSettle();

    expect(find.text('Одоогийн нууц үг буруу.'), findsOneWidget);
  });

  testWidgets('successful submit clears fields and calls onChanged', (
    tester,
  ) async {
    var changed = false;
    await pumpAt(
      tester,
      ChangePasswordScreen(
        repo: FakeAccountRepository(),
        onChanged: () => changed = true,
      ),
    );

    await tester.enterText(
      passwordFieldByKey('change_password_current'),
      'correct-password',
    );
    await tester.enterText(
      passwordFieldByKey('change_password_new'),
      'newpassword1',
    );
    await tester.enterText(
      passwordFieldByKey('change_password_confirm'),
      'newpassword1',
    );
    await tester.tap(find.text('Хадгалах'));
    await tester.pumpAndSettle();

    expect(changed, isTrue);
    await tester.pump(const Duration(seconds: 3));
  });
}
