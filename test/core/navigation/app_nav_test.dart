import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:carservice_business/core/navigation/app_nav.dart';

void main() {
  group('AppNav.toNamed', () {
    setUp(() {
      AppNav.currentTab = null;
      AppNav.addPages({
        '/test-page': (context, arguments) => Scaffold(
          body: Text(
            'page $arguments '
            '${ModalRoute.of(context)!.settings.name} '
            '${ModalRoute.of(context)!.settings.arguments}',
          ),
        ),
      });
    });

    testWidgets('builds the named page with its arguments and hands back the '
        'result', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: SizedBox()));

      final result = AppNav.toNamed<String>('/test-page', arguments: 42);
      await tester.pumpAndSettle();
      expect(find.text('page 42 /test-page 42'), findsOneWidget);

      AppNav.back('done');
      await tester.pumpAndSettle();
      expect(await result, 'done');
      expect(find.textContaining('page'), findsNothing);
    });

    testWidgets('an unregistered name throws', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: SizedBox()));

      expect(() => AppNav.toNamed<void>('/missing'), throwsArgumentError);
    });
  });
}
