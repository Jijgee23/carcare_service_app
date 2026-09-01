import 'package:carcare_service/core/api/api_client.dart';
import 'package:carcare_service/core/error/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/models/appointment.dart';
import 'package:intl/intl.dart';

class AppointmentRepository {
  static final _dateFmt = DateFormat('yyyy-MM-dd');

  Future<Result<Map<String, int>>> getMonthCounts({
    required int year,
    required int month,
    String? branchId,
  }) async {
    final monthStr =
        '$year-${month.toString().padLeft(2, '0')}';
    final q = [
      'month=$monthStr',
      if (branchId != null) 'branchId=$branchId',
    ].join('&');
    try {
      final res = await apiOrThrow(Api.get, 'appointments?$q');
      final dates = (res.data['dates'] as List).cast<String>();
      final counts = <String, int>{};
      for (final d in dates) {
        counts[d] = (counts[d] ?? 0) + 1;
      }
      return Ok(counts);
    } on AppError catch (e) {
      return Err(e);
    }
  }

  Future<Result<List<AppointmentSummary>>> getAppointments({
    DateTime? date,
    AppointmentStatus? status,
    String? branchId,
    int page = 1,
    int pageSize = 50,
  }) async {
    final q = [
      'page=$page',
      'pageSize=$pageSize',
      if (date != null) 'date=${_dateFmt.format(date)}',
      if (status != null) 'status=${status.name}',
      if (branchId != null) 'branchId=$branchId',
    ].join('&');
    try {
      final res = await apiOrThrow(Api.get, 'appointments?$q');
      final list = res.data['appointments'] as List;
      return Ok(
        list
            .map((e) =>
                AppointmentSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on AppError catch (e) {
      return Err(e);
    }
  }

  Future<Result<AppointmentSummary>> updateStatus(
    String id,
    AppointmentStatus status,
  ) async {
    try {
      final res = await apiOrThrow(
        Api.patch,
        'appointments/$id',
        body: {'status': status.name},
      );
      return Ok(AppointmentSummary.fromJson(
          res.data['appointment'] as Map<String, dynamic>));
    } on AppError catch (e) {
      return Err(e);
    }
  }

  Future<Result<AppointmentSummary>> createAppointment({
    required String branchId,
    required DateTime requestedAt,
    String? customerId,
    String? vehicleId,
    String? phone,
    String? name,
    String? note,
  }) async {
    try {
      final res = await apiOrThrow(
        Api.post,
        'appointments',
        body: {
          'branchId': branchId,
          'requestedAt': requestedAt.toIso8601String(),
          if (customerId != null && customerId.isNotEmpty) 'customerId': customerId,
          if (vehicleId != null && vehicleId.isNotEmpty) 'vehicleId': vehicleId,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          if (name != null && name.isNotEmpty) 'name': name,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );
      return Ok(AppointmentSummary.fromJson(
          res.data['appointment'] as Map<String, dynamic>));
    } on AppError catch (e) {
      return Err(e);
    }
  }
}
