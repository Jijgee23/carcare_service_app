import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fake_account_repository.dart';

void main() {
  User user() => User(
    accessToken: 'token',
    refreshToken: 'refresh',
    id: 'u-1',
    email: 'oyunaa@example.test',
    firstName: 'Оюунаа',
    lastName: 'Батаа',
    phone: '99112233',
    isOwner: false,
    tenant: UserTenant('t-1', 'Карком'),
  );

  Future<void> pumpAt(WidgetTester tester, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  testWidgets('renders prefilled from the given user', (tester) async {
    await pumpAt(
      tester,
      EditProfileScreen(repo: FakeAccountRepository(), user: user()),
    );

    expect(find.text('Профайл засах'), findsOneWidget);
    expect(find.text('Батаа'), findsOneWidget);
    expect(find.text('Оюунаа'), findsOneWidget);
    expect(find.text('oyunaa@example.test'), findsOneWidget);
    expect(find.text('99112233'), findsOneWidget);
  });

  testWidgets('no horizontal overflow at 375dp', (tester) async {
    await pumpAt(
      tester,
      EditProfileScreen(repo: FakeAccountRepository(), user: user()),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows server fieldErrors inline and does not call onSaved', (
    tester,
  ) async {
    User? saved;
    final repo = FakeAccountRepository();
    await pumpAt(
      tester,
      EditProfileScreen(repo: repo, user: user(), onSaved: (u) => saved = u),
    );

    await tester.enterText(
      find.byKey(const ValueKey('edit_profile_first_name')),
      '',
    );
    await tester.tap(find.text('Хадгалах'));
    await tester.pumpAndSettle();

    expect(find.text('Нэрээ оруулна уу.'), findsOneWidget);
    expect(saved, isNull);
  });

  testWidgets('successful save invokes onSaved with the updated user', (
    tester,
  ) async {
    User? saved;
    final repo = FakeAccountRepository();
    await pumpAt(
      tester,
      EditProfileScreen(repo: repo, user: user(), onSaved: (u) => saved = u),
    );

    await tester.enterText(
      find.byKey(const ValueKey('edit_profile_first_name')),
      'Сараа',
    );
    await tester.tap(find.text('Хадгалах'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.firstName, 'Сараа');
    await tester.pump(const Duration(seconds: 3));
  });
}
