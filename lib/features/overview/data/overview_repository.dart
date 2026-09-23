import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/overview/data/overview_data_source.dart';
import 'package:carcare_service/features/overview/data/overview_dto.dart';
import 'package:carcare_service/features/overview/domain/overview.dart';
import 'package:carcare_service/features/overview/domain/overview_repository.dart';

/// Remote adapter for [OverviewRepository] — P7-F1.
class RemoteOverviewRepository implements OverviewRepository {
  RemoteOverviewRepository({OverviewDataSource? dataSource})
    : _dataSource = dataSource ?? RemoteOverviewDataSource();

  final OverviewDataSource _dataSource;

  @override
  Future<Result<Overview>> getOverview({OverviewRangeQuery? query}) async {
    final effective = query ?? const OverviewRangeQuery();
    try {
      return Ok(
        OverviewDto.fromJson(
          await _dataSource.get({
            if (effective.range != null && effective.range!.isNotEmpty)
              'range': effective.range,
            if (effective.from != null && effective.from!.isNotEmpty)
              'from': effective.from,
            if (effective.to != null && effective.to!.isNotEmpty)
              'to': effective.to,
          }),
        ).value,
      );
    } catch (error) {
      return Err(_error(error, 'Тойм мэдээлэл ачаалж чадсангүй'));
    }
  }
}

AppError _error(Object error, String fallback) => switch (error) {
  AppError value => value,
  OverviewParseException value => AppError(ErrorKind.unknown, value.message),
  _ => AppError(ErrorKind.unknown, fallback),
};
