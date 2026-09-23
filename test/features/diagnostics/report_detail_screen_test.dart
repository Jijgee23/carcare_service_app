import 'package:carcare_service/features/diagnostics/presentation/screens/report_detail_screen.dart';
import 'package:carcare_service/core/domain/user.dart';
import 'package:carcare_service/core/widgets/adaptive/permission_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tone counts only include the three diagnostic answer values', () {
    final counts = diagnosticToneCounts([
      'OK',
      'Засах',
      'Анхаарах',
      'Засах',
      'Free text',
      null,
    ]);

    expect(counts[DiagnosticAnswerTone.good], 1);
    expect(counts[DiagnosticAnswerTone.warn], 1);
    expect(counts[DiagnosticAnswerTone.bad], 2);
    expect(counts.values.reduce((a, b) => a + b), 4);
  });

  test('all tone includes every answer and individual tones match only their value', () {
    expect(
      diagnosticAnswerMatchesTone('Free text', DiagnosticAnswerTone.all),
      isTrue,
    );
    expect(diagnosticAnswerMatchesTone('OK', DiagnosticAnswerTone.all), isTrue);
    expect(
      diagnosticAnswerMatchesTone('OK', DiagnosticAnswerTone.good),
      isTrue,
    );
    expect(
      diagnosticAnswerMatchesTone('Анхаарах', DiagnosticAnswerTone.good),
      isFalse,
    );
  });

  test(
    'delete affordance allows view permission, report creator, or owner',
    () {
      User makeUser({
        bool owner = false,
        List<String> permissions = const [],
      }) => User(
        accessToken: '',
        refreshToken: '',
        id: 'staff-1',
        email: '',
        firstName: '',
        lastName: '',
        phone: '',
        isOwner: owner,
        role: UserRole('role-1', 'Staff', permissions),
        tenant: UserTenant('tenant-1', 'Tenant'),
      );

      expect(
        canDeleteDiagnosticReport(user: makeUser(), filledById: 'staff-2'),
        isFalse,
      );
      expect(
        canDeleteDiagnosticReport(user: makeUser(), filledById: 'staff-1'),
        isTrue,
      );
      expect(
        canDeleteDiagnosticReport(
          user: makeUser(permissions: ['diagnostics.delete']),
          filledById: 'staff-2',
        ),
        isTrue,
      );
      expect(
        canDeleteDiagnosticReport(
          user: makeUser(owner: true),
          filledById: 'staff-2',
        ),
        isTrue,
      );
      expect(canSeeView(makeUser(), 'diagnostics.view'), isFalse);
      expect(
        canSeeView(
          makeUser(permissions: ['diagnostics.view', 'diagnostics.create']),
          'diagnostics.view',
        ),
        isTrue,
      );
      expect(
        canSeeView(
          makeUser(permissions: ['diagnostics.view', 'diagnostics.create']),
          'diagnostics.create',
        ),
        isTrue,
      );
    },
  );
}
