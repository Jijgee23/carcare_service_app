import 'package:carcare_service/core/network/api_client.dart';
import 'package:carcare_service/core/network/working_branch_interceptor.dart';
import 'package:carcare_service/features/shell/domain/working_branch.dart';
import 'package:dio/dio.dart';

/// Dio-backed adapter for the current user's working-branch choices.
class RemoteWorkingBranchRepository implements WorkingBranchRepository {
  final Dio dio;

  RemoteWorkingBranchRepository({Dio? dio})
    : dio = dio ?? ApiService.instance.dio;

  @override
  Future<WorkingBranchOptions> fetchOptions() async {
    final response = await dio.get('branches/switchable');
    return WorkingBranchOptions.fromJson(response.data);
  }
}
