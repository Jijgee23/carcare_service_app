import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/employees/data/employee_dto.dart';
import 'package:carcare_service/features/employees/data/employees_data_source.dart';
import 'package:carcare_service/features/employees/domain/employee.dart';
import 'package:carcare_service/features/employees/domain/employees_repository.dart';

/// Remote adapter for [EmployeesRepository] — P6-F1. JSON and Dio stay below
/// the repository contract; controllers depend on [EmployeesRepository] or a
/// fake, matching `RemoteServicesRepository`.
class RemoteEmployeesRepository implements EmployeesRepository {
  RemoteEmployeesRepository({EmployeesDataSource? dataSource})
    : _dataSource = dataSource ?? RemoteEmployeesDataSource();

  final EmployeesDataSource _dataSource;

  @override
  Future<Result<EmployeePage>> getEmployees({EmployeeListQuery? query}) async {
    final effective = query ?? const EmployeeListQuery();
    try {
      return Ok(
        EmployeePageDto.fromJson(await _dataSource.list(_listQuery(effective)))
            .value,
      );
    } catch (error) {
      return Err(_error(error, 'Ажилтны жагсаалт ачаалж чадсангүй'));
    }
  }

  @override
  Future<Result<Employee>> getEmployee(String employeeId) async {
    try {
      return Ok(
        EmployeeDto.fromJson(await _dataSource.detail(employeeId)).value,
      );
    } catch (error) {
      return Err(_error(error, 'Ажилтны мэдээлэл ачаалж чадсангүй'));
    }
  }

  @override
  Future<Result<Employee>> createEmployee({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    String? roleId,
    String? branchId,
    List<String> assignableBranchIds = const [],
    bool isActive = true,
    DateTime? activeUntil,
    bool isOwner = false,
  }) async {
    try {
      return Ok(
        EmployeeDto.fromJson(
          await _dataSource.create({
            'firstName': firstName,
            'lastName': lastName,
            'email': email,
            'phone': phone,
            'roleId': roleId,
            'branchId': branchId,
            'assignableBranchIds': assignableBranchIds,
            'isActive': isActive,
            if (activeUntil != null)
              'activeUntil': activeUntil.toUtc().toIso8601String(),
            if (isOwner) 'isOwner': true,
          }),
        ).value,
      );
    } catch (error) {
      return Err(_error(error, 'Ажилтан үүсгэж чадсангүй'));
    }
  }

  @override
  Future<Result<Employee>> updateEmployee(
    String employeeId, {
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    String? roleId,
    String? branchId,
    List<String> assignableBranchIds = const [],
    bool isActive = true,
    DateTime? activeUntil,
  }) async {
    try {
      // Whole-record replace: every editable field is sent every time,
      // including an explicit `null` for an omitted optional one — see the
      // repository interface's doc comment.
      return Ok(
        EmployeeDto.fromJson(
          await _dataSource.update(employeeId, {
            'firstName': firstName,
            'lastName': lastName,
            'email': email,
            'phone': phone,
            'roleId': roleId,
            'branchId': branchId,
            'assignableBranchIds': assignableBranchIds,
            'isActive': isActive,
            'activeUntil': activeUntil?.toUtc().toIso8601String(),
          }),
        ).value,
      );
    } catch (error) {
      return Err(_error(error, 'Ажилтны мэдээлэл хадгалж чадсангүй'));
    }
  }

  @override
  Future<Result<EmployeeIdResult>> deleteEmployee(String employeeId) async {
    try {
      return Ok(
        EmployeeIdResultDto.fromJson(await _dataSource.delete(employeeId))
            .value,
      );
    } catch (error) {
      return Err(_error(error, 'Ажилтан устгаж чадсангүй'));
    }
  }

  @override
  Future<Result<EmployeeToggleResult>> toggleActive(
    String employeeId, {
    required bool isActive,
  }) async {
    try {
      return Ok(
        EmployeeToggleResultDto.fromJson(
          await _dataSource.toggleActive(employeeId, {'isActive': isActive}),
        ).value,
      );
    } catch (error) {
      return Err(_error(error, 'Ажилтны төлөв солиход алдаа гарлаа'));
    }
  }

  @override
  Future<Result<EmployeeIdResult>> resetPassword(String employeeId) async {
    try {
      return Ok(
        EmployeeIdResultDto.fromJson(
          await _dataSource.resetPassword(employeeId),
        ).value,
      );
    } catch (error) {
      return Err(_error(error, 'Нууц үг дахин тохируулж чадсангүй'));
    }
  }

  @override
  Future<Result<EmployeeBulkResult>> bulkUpdateRoleBranch({
    required List<String> employeeIds,
    String? roleId,
    String? branchId,
  }) async {
    try {
      return Ok(
        EmployeeBulkResultDto.fromJson(
          await _dataSource.bulk({
            'employeeIds': employeeIds,
            if (roleId != null && roleId.isNotEmpty) 'roleId': roleId,
            if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
          }),
        ).value,
      );
    } catch (error) {
      return Err(_error(error, 'Багцаар шинэчлэхэд алдаа гарлаа'));
    }
  }
}

Map<String, dynamic> _listQuery(EmployeeListQuery query) => {
  'page': query.page,
  'pageSize': query.pageSize,
  if (query.q != null && query.q!.trim().isNotEmpty) 'q': query.q!.trim(),
  if (query.branchId != null && query.branchId!.isNotEmpty)
    'branchId': query.branchId,
  if (query.roleId != null && query.roleId!.isNotEmpty) 'roleId': query.roleId,
  if (query.active != null) 'active': query.active! ? 'yes' : 'no',
};

AppError _error(Object error, String fallback) => switch (error) {
  AppError value => value,
  EmployeeParseException value => AppError(ErrorKind.unknown, value.message),
  _ => AppError(ErrorKind.unknown, fallback),
};
