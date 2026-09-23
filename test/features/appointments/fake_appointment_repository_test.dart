import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/appointments/domain/appointment.dart';
import 'package:carcare_service/features/appointments/domain/appointments_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_appointment_repository.dart';

/// Ported to the P2-F1 frozen `AppointmentsRepository` contract — P2-F2.
///
/// The pre-programme repository this file originally exercised exposed
/// `getAppointments(status:, branchId:, date:)` returning a bare list,
/// `updateStatus(id, status)`, `createAppointment(phone:, name:)` (walk-in
/// creation with no customer id) and `getMonthCounts(...)`. None of those
/// exist on the frozen `AppointmentsRepository` — `getAppointments` takes an
/// `AppointmentListQuery` and returns a `PagedResult`, status changes are
/// four named lifecycle methods (`confirm`/`reject`/`markNoShow`/`cancel`)
/// plus `PATCH .../cancel`, and `createAppointment` requires a `customerId`.
///
/// The `getMonthCounts` case is dropped rather than ported, but note the
/// reason is a CONTRACT gap, not a missing server feature: `GET
/// /api/v1/appointments` does support `?month=YYYY-MM`, returning
/// `{dates: string[]}` for calendar dot counts. The frozen P2-F1
/// `AppointmentsRepository` simply does not expose it yet. Whichever slice
/// wants month dots should widen the contract rather than re-deriving counts
/// on the client.
void main() {
  test('getAppointments lists the seeded appointment', () async {
    final repo = FakeAppointmentRepository();

    final result = await repo.getAppointments();

    final page = (result as Ok<PagedResult<AppointmentSummary>>).value;
    expect(page.items, hasLength(1));
    expect(page.items.single.status, AppointmentStatus.PENDING);
  });

  test('getAppointments filters by status', () async {
    final repo = FakeAppointmentRepository();

    final result = await repo.getAppointments(
      query: const AppointmentListQuery(status: AppointmentStatus.CONFIRMED),
    );

    final page = (result as Ok<PagedResult<AppointmentSummary>>).value;
    expect(page.items, isEmpty);
  });

  test('confirm mutates the stored appointment', () async {
    final repo = FakeAppointmentRepository();

    final result = await repo.confirm('appt-1');

    expect((result as Ok).value.status, AppointmentStatus.CONFIRMED);
    final list = await repo.getAppointments(
      query: const AppointmentListQuery(status: AppointmentStatus.CONFIRMED),
    );
    expect(
      (list as Ok<PagedResult<AppointmentSummary>>).value.items,
      hasLength(1),
    );
  });

  test('confirm reports not-found for an unknown id', () async {
    final repo = FakeAppointmentRepository();

    final result = await repo.confirm('missing');

    expect(result, isA<Err>());
  });

  group('getAppointments — q search (mirrors the shared five-clause OR)', () {
    // Mirrors `appointmentSearchWhere` in
    // `carcare.mn/lib/appointments/appointment-list-query.ts`, which since
    // P2-B9 also backs the web dashboard, so both surfaces search alike:
    // account name (case-insensitive), account phone (case-sensitive),
    // customer fullName (case-insensitive), customer phone
    // (case-sensitive), note (case-insensitive).
    final withMatches = [
      const AppointmentAccountRef(name: 'Болд Ганбат', phone: '99112233'),
    ];

    AppointmentSummary appt({
      String id = 'a1',
      AppointmentAccountRef? account,
      String? note,
    }) => AppointmentSummary(
      id: id,
      status: AppointmentStatus.PENDING,
      requestedAt: DateTime(2026, 9, 22, 10),
      branch: const AppointmentBranchRef(id: 'branch-1'),
      account: account,
      note: note,
    );

    test('matches account name case-insensitively', () async {
      final repo = FakeAppointmentRepository(
        seed: [
          appt(account: withMatches.first),
          appt(id: 'a2'),
        ],
      );

      final result = await repo.getAppointments(
        query: const AppointmentListQuery(q: 'ганбат'),
      );

      final page = (result as Ok<PagedResult<AppointmentSummary>>).value;
      expect(page.items.map((a) => a.id), ['a1']);
    });

    test(
      'matches account phone case-sensitively (exact digits only)',
      () async {
        final repo = FakeAppointmentRepository(
          seed: [
            appt(account: withMatches.first),
            appt(id: 'a2'),
          ],
        );

        final result = await repo.getAppointments(
          query: const AppointmentListQuery(q: '9911'),
        );

        final page = (result as Ok<PagedResult<AppointmentSummary>>).value;
        expect(page.items.map((a) => a.id), ['a1']);
      },
    );

    test('phone match is case-sensitive: an uppercased query does not "case-fold" match digits', () async {
      // Phone numbers have no case, so this is really just documenting
      // that the phone clause uses a plain `contains`, never
      // `toLowerCase()` normalization, unlike the name/note clauses.
      final repo = FakeAppointmentRepository(
        seed: [appt(account: withMatches.first)],
      );

      final result = await repo.getAppointments(
        query: const AppointmentListQuery(q: '99112233'),
      );

      final page = (result as Ok<PagedResult<AppointmentSummary>>).value;
      expect(page.items, hasLength(1));
    });

    test('matches note case-insensitively', () async {
      final repo = FakeAppointmentRepository(
        seed: [
          appt(note: 'Тос сольсон, дугуй шалгах'),
          appt(id: 'a2', note: 'Өөр'),
        ],
      );

      final result = await repo.getAppointments(
        query: const AppointmentListQuery(q: 'ТОС СОЛЬСОН'),
      );

      final page = (result as Ok<PagedResult<AppointmentSummary>>).value;
      expect(page.items.map((a) => a.id), ['a1']);
    });

    // P2-B9 inverted this. It previously asserted that customer fullName was
    // NOT searchable, which mirrored the server at the time. That was the
    // bug: a staff-registered appointment is booked against a tenant
    // Customer and carries no account at all, so the person who booked it
    // could not be found by their own name or phone — on either surface.
    test('matches on customer fullName, case-insensitively', () async {
      final repo = FakeAppointmentRepository(
        seed: [
          AppointmentSummary(
            id: 'a1',
            status: AppointmentStatus.PENDING,
            requestedAt: DateTime(2026, 9, 22, 10),
            branch: const AppointmentBranchRef(id: 'branch-1'),
            customer: const AppointmentCustomerRef(fullName: 'Special Name'),
          ),
          appt(id: 'a2'),
        ],
      );

      final result = await repo.getAppointments(
        query: const AppointmentListQuery(q: 'special'),
      );

      final page = (result as Ok<PagedResult<AppointmentSummary>>).value;
      expect(page.items.map((a) => a.id), ['a1']);
    });

    test(
      'matches on customer phone, case-sensitively like the server',
      () async {
        final repo = FakeAppointmentRepository(
          seed: [
            AppointmentSummary(
              id: 'a1',
              status: AppointmentStatus.PENDING,
              requestedAt: DateTime(2026, 9, 22, 10),
              branch: const AppointmentBranchRef(id: 'branch-1'),
              customer: const AppointmentCustomerRef(
                fullName: 'Walk-in',
                phone: '88776655',
              ),
            ),
            appt(id: 'a2'),
          ],
        );

        final result = await repo.getAppointments(
          query: const AppointmentListQuery(q: '8877'),
        );

        final page = (result as Ok<PagedResult<AppointmentSummary>>).value;
        expect(page.items.map((a) => a.id), ['a1']);
      },
    );

    test('a whitespace-only q behaves as absent (no filtering)', () async {
      final repo = FakeAppointmentRepository(
        seed: [
          appt(id: 'a1'),
          appt(id: 'a2'),
        ],
      );

      final result = await repo.getAppointments(
        query: const AppointmentListQuery(q: '   '),
      );

      final page = (result as Ok<PagedResult<AppointmentSummary>>).value;
      expect(page.items, hasLength(2));
    });

    test('composes with status/branch/date filters (AND, not OR)', () async {
      final repo = FakeAppointmentRepository(
        seed: [
          appt(id: 'a1', account: withMatches.first),
          AppointmentSummary(
            id: 'a2',
            status: AppointmentStatus.CONFIRMED,
            requestedAt: DateTime(2026, 9, 22, 10),
            branch: const AppointmentBranchRef(id: 'branch-1'),
            account: withMatches.first,
          ),
        ],
      );

      final result = await repo.getAppointments(
        query: const AppointmentListQuery(
          q: 'Ганбат',
          status: AppointmentStatus.CONFIRMED,
        ),
      );

      final page = (result as Ok<PagedResult<AppointmentSummary>>).value;
      expect(page.items.map((a) => a.id), ['a2']);
    });
  });

  test(
    'createAppointment appends a new appointment for the given customer',
    () async {
      final repo = FakeAppointmentRepository();

      final result = await repo.createAppointment(
        branchId: 'branch-1',
        customerId: 'cust-2',
        requestedAt: DateTime.now().add(const Duration(days: 1)),
      );

      expect((result as Ok).value.status, AppointmentStatus.CONFIRMED);
      final list = await repo.getAppointments();
      expect(
        (list as Ok<PagedResult<AppointmentSummary>>).value.items,
        hasLength(2),
      );
    },
  );
}
