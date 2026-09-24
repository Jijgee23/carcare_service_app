import 'dart:io';

import 'package:carcare_service/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

// P0-F3 (TENANT_MOBILE_SLICES.md): the Ops Console theme port.
//
// Covers exactly what the slice asked to verify: both themes build, and
// ThemeProvider.toggleTheme() actually reaches ThemeMode.light. The last
// test is a regression test for a real bug found in this file — the `if`
// branch that set `mode = ThemeMode.light` had no `return`, so every call
// fell through and unconditionally set `mode = ThemeMode.dark` again,
// making light mode unreachable once you'd ever left it. Confirmed this
// test fails against that pre-fix version (temporarily restored it locally,
// watched this test go red, then restored the fix) before finalizing.
//
// `ThemeProvider` opens a real Hive box for persistence (see its doc comment
// for why it isn't `auth_storage.dart`'s typed-box pattern verbatim), but
// both the restore-on-construct and persist-on-toggle paths are fire-and-
// forget by design — `toggleTheme()`'s in-memory flip never awaits the Hive
// write, so a slow or contended box can't block or hang a caller.
//
// This file initializes its own throwaway Hive instance (`setUpAll`/
// `tearDownAll` below) rather than relying on `test/flutter_test_config.dart`
// (P0-F4's file, not this slice's): without *some* `Hive.init`, a failed
// `Hive.openBox` doesn't just reject its own Future — it also completes an
// internal orphaned `Completer` in `hive_impl.dart`'s `_openBox` that nothing
// awaits, which Flutter's test framework reports as an uncaught error
// regardless of this file's own try/catch. Owning this file's Hive setup
// keeps it correct on its own, independent of another slice's file.
//
// There's no "persists across instances" test here: asserting a
// fire-and-forget write landed before a fresh instance's fire-and-forget
// read is a race by construction. Persistence itself is covered by code
// review of `_persist`/`_restore` (same box/key, symmetric encode/decode);
// what's regression-tested here is the pure, synchronous toggle bug.
void main() {
  late Directory hiveDir;

  setUpAll(() {
    hiveDir = Directory.systemTemp.createTempSync('carcare_theme_test_hive');
    Hive.init(hiveDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (hiveDir.existsSync()) hiveDir.deleteSync(recursive: true);
  });

  testWidgets('AppTheme.light builds and renders without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: Center(child: Text('light ok'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('light ok'), findsOneWidget);
  });

  testWidgets('AppTheme.dark builds and renders without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: Center(child: Text('dark ok'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('dark ok'), findsOneWidget);
  });

  testWidgets('runtime palette and typography work without a theme extension', (
    tester,
  ) async {
    Color? fallbackInk;
    Color? fallbackAccent;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            fallbackInk = context.colors.textPrimary;
            fallbackAccent = context.colors.accent;
            return Text('fallback', style: context.textStyles.body);
          },
        ),
      ),
    );
    await tester.pump();

    expect(fallbackInk, ThemeData().colorScheme.onSurface);
    expect(fallbackAccent, ThemeData().colorScheme.primary);
    expect(find.text('fallback'), findsOneWidget);

    Color? lightInk;
    Color? darkInk;
    Color? lightPrimitiveInk;
    Color? darkPrimitiveInk;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        themeAnimationDuration: Duration.zero,
        home: Builder(
          builder: (context) {
            lightInk = context.textStyles.body.color;
            lightPrimitiveInk = context.colors.textPrimary;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        themeAnimationDuration: Duration.zero,
        home: Builder(
          builder: (context) {
            darkInk = context.textStyles.body.color;
            darkPrimitiveInk = context.colors.textPrimary;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();

    final lightColors = AppTheme.light.extension<CarCareTheme>()!;
    final darkColors = AppTheme.dark.extension<CarCareTheme>()!;
    expect(lightInk, lightColors.ink);
    expect(darkInk, darkColors.ink);
    expect(lightPrimitiveInk, lightColors.ink);
    expect(darkPrimitiveInk, darkColors.ink);
    expect(lightInk, isNot(darkInk));
    expect(lightPrimitiveInk, isNot(darkPrimitiveInk));
  });

  testWidgets(
    'toggleTheme() reaches ThemeMode.light again after a second toggle',
    (tester) async {
      final provider = ThemeProvider();
      // Let the constructor's fire-and-forget Hive restore complete (there's
      // nothing persisted yet, so this resolves to the ThemeMode.light default)
      // before asserting anything.
      await tester.pump();

      expect(
        provider.mode,
        ThemeMode.light,
        reason: 'default before any toggle',
      );

      await provider.toggleTheme();
      expect(provider.mode, ThemeMode.dark);

      await provider.toggleTheme();
      expect(
        provider.mode,
        ThemeMode.light,
        reason:
            'Without the fix, the missing `return` meant this second call fell '
            'through and forced mode back to dark, so light was unreachable.',
      );
    },
  );

  testWidgets('setMode() picks system/light/dark and notifies once each', (
    tester,
  ) async {
    final provider = ThemeProvider();
    await tester.pump();
    var notified = 0;
    provider.addListener(() => notified++);

    provider.setMode(ThemeMode.system);
    expect(provider.mode, ThemeMode.system);
    provider.setMode(ThemeMode.system); // no-op
    provider.setMode(ThemeMode.dark);
    expect(provider.mode, ThemeMode.dark);
    provider.setMode(ThemeMode.light);
    expect(provider.mode, ThemeMode.light);
    expect(notified, 3);
  });

  testWidgets('segmented control switches the mode', (tester) async {
    final provider = ThemeProvider();
    await tester.pump();
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Consumer<ThemeProvider>(
              builder: (_, t, _) => SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('Системийн'),
                  ),
                  ButtonSegment(value: ThemeMode.light, label: Text('Цайвар')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Бараан')),
                ],
                selected: {t.mode},
                onSelectionChanged: (s) => t.setMode(s.first),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Бараан'));
    await tester.pump();
    expect(provider.mode, ThemeMode.dark);
    await tester.tap(find.text('Системийн'));
    await tester.pump();
    expect(provider.mode, ThemeMode.system);
  });
}
