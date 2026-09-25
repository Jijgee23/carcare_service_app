import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/features/reports/domain/report.dart';
import 'package:carcare_service/features/reports/presentation/screens/reports_screen.dart';

import '../../data/fake_reports_repository.dart';

void main() {
  User user() => User(
    accessToken: 'token',
    refreshToken: 'refresh',
    id: 'user',
    email: 'user@example.test',
    firstName: 'Test',
    lastName: 'User',
    phone: '99001122',
    isOwner: false,
    role: UserRole('role', 'Role', const []),
    tenant: UserTenant('tenant', 'Tenant'),
  );

  Future<void> pumpAt(WidgetTester tester, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pump();
    await tester.pump();
  }

  ReportData sampleData() => const ReportData(
    totalRevenue: 1500000,
    completedCount: 12,
    avgTicket: 125000,
    activeCount: 3,
    avgJobDurationMinutes: 95,
    statusRows: [
      ReportStatusRow(status: 'DONE', label: 'Дууссан', count: 12, pct: 80),
      ReportStatusRow(
        status: 'IN_PROGRESS',
        label: 'Явагдаж буй',
        count: 3,
        pct: 20,
      ),
    ],
    kindRows: [
      ReportKindRow(kind: 'SERVICE', label: 'Ажил', total: 900000, pct: 60),
      ReportKindRow(kind: 'PART', label: 'Сэлбэг', total: 600000, pct: 40),
    ],
    branchRows: [
      ReportBranchRow(id: 'b1', name: 'Төв салбар', revenue: 1000000, count: 8),
    ],
    techRows: [ReportTechRow(id: 't1', name: 'Бат', revenue: 700000, count: 5)],
    jobDurationRows: [
      ReportJobDurationRow(
        id: 'j1',
        name: 'Тос солих',
        count: 6,
        avgMinutes: 45,
      ),
    ],
    customerRows: [
      ReportCustomerRow(
        id: 'c1',
        name: 'Дорж',
        phone: '99001122',
        revenue: 300000,
        count: 2,
      ),
    ],
    partRows: [
      ReportPartRow(
        id: 'p1',
        name: 'Тос шүүлтүүр',
        sku: 'SKU-1',
        unit: 'ш',
        qty: 3,
        revenue: 45000,
      ),
    ],
    income: ReportIncome(
      changePct: 12.5,
      points: [
        ReportIncomePoint(label: '09-01', value: 100000),
        ReportIncomePoint(label: '09-02', value: 200000),
      ],
    ),
  );

  group('ReportsScreen', () {
    testWidgets('renders KPI cards and section headers, no overflow at 375dp', (
      tester,
    ) async {
      await pumpAt(
        tester,
        ReportsScreen(
          repository: FakeReportsRepository(data: sampleData()),
          user: user(),
        ),
      );

      expect(find.text('Тайлан'), findsWidgets);
      expect(find.text('Нийт орлого'), findsOneWidget);
      expect(find.text('Орлогын хандлага'), findsOneWidget);
      expect(find.text('Засварын хуудасны статус'), findsOneWidget);
      expect(find.text('Салбараар'), findsOneWidget);
      expect(find.text('Мастер / Менежер'), findsOneWidget);
      expect(find.text('Топ үйлчлүүлэгчид'), findsOneWidget);
      expect(find.text('Топ сэлбэгүүд'), findsOneWidget);
      expect(find.text('Ажлын гүйцэтгэх дундаж хугацаа'), findsOneWidget);
      expect(find.text('Төв салбар'), findsOneWidget);
      expect(find.text('Дорж'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows empty placeholders for empty sections', (tester) async {
      await pumpAt(
        tester,
        ReportsScreen(
          repository: FakeReportsRepository(data: const ReportData()),
          user: user(),
        ),
      );
      expect(find.text('Өгөгдөл алга.'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('filter sheet switches the quick range and reloads', (
      tester,
    ) async {
      final repo = FakeReportsRepository(data: sampleData());
      await pumpAt(tester, ReportsScreen(repository: repo, user: user()));
      // No inline chips any more — the period lives behind the filter.
      expect(find.text('Энэ жил'), findsNothing);
      expect(find.byIcon(Icons.filter_alt_outlined), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('report_filter_button')));
      await tester.pumpAndSettle();
      final before = repo.getCalls;
      await tester.tap(find.text('Энэ жил'));
      await tester.pump();
      expect(repo.getCalls, before); // nothing applied until "Хэрэглэх"
      await tester.tap(find.byKey(const ValueKey('report_filter_apply')));
      await tester.pumpAndSettle();

      expect(repo.getCalls, greaterThan(before));
      expect(find.byIcon(Icons.filter_alt), findsOneWidget); // active state
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('report_period_pill')),
          matching: find.textContaining('Энэ жил', findRichText: true),
        ),
        findsWidgets,
      ); // period pill label
    });

    testWidgets('dismissing the filter sheet changes nothing', (tester) async {
      final repo = FakeReportsRepository(data: sampleData());
      await pumpAt(tester, ReportsScreen(repository: repo, user: user()));
      await tester.tap(find.byKey(const ValueKey('report_period_pill')));
      await tester.pumpAndSettle();
      final before = repo.getCalls;
      await tester.tap(find.text('Өнгөрсөн сар'));
      await tester.pump();
      await tester.tapAt(const Offset(10, 10)); // barrier
      await tester.pumpAndSettle();
      expect(repo.getCalls, before);
      expect(find.byIcon(Icons.filter_alt_outlined), findsOneWidget);
    });

    testWidgets('custom range from the sheet is applied', (tester) async {
      final repo = FakeReportsRepository(data: sampleData());
      await pumpAt(tester, ReportsScreen(repository: repo, user: user()));
      await tester.tap(find.byKey(const ValueKey('report_filter_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('report_filter_custom')));
      await tester.pumpAndSettle();
      // Date picker opens pre-filled with this month; confirm it as-is.
      await tester.tap(find.byKey(const ValueKey('app_date_picker_confirm')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('report_filter_apply')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('report_period_pill')),
          matching: find.textContaining('Сонгосон хугацаа', findRichText: true),
        ),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('export happy path calls the injected export hook', (
      tester,
    ) async {
      String? sharedName;
      await pumpAt(
        tester,
        ReportsScreen(
          repository: FakeReportsRepository(data: sampleData()),
          user: user(),
          onExport: (bytes, filename) async {
            sharedName = filename;
          },
        ),
      );
      await tester.tap(find.byTooltip('Excel татах'));
      await tester.pump();
      await tester.pump();
      expect(sharedName, isNotNull);
      expect(sharedName, endsWith('.xlsx'));
    });

    testWidgets('export failure shows an error message, not a crash', (
      tester,
    ) async {
      final repo = FakeReportsRepository(data: sampleData())..failExport = true;
      await pumpAt(
        tester,
        ReportsScreen(
          repository: repo,
          user: user(),
          onExport: (bytes, filename) async {
            fail('should not be called on export failure');
          },
        ),
      );
      await tester.tap(find.byTooltip('Excel татах'));
      await tester.pumpAndSettle(const Duration(seconds: 4));
      expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows a loading indicator before data arrives', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: ReportsScreen(
            repository: FakeReportsRepository(data: sampleData()),
            user: user(),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
