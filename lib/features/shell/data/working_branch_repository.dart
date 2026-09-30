import 'package:carservice_business/core/network/api_client.dart';
import 'package:carservice_business/core/network/working_branch_interceptor.dart';
import 'package:carservice_business/features/shell/domain/working_branch.dart';
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
