import 'package:carcare_service/core/domain/pagination.dart';
import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/feedback/data/feedback_data_source.dart';
import 'package:carcare_service/features/feedback/data/feedback_dto.dart';
import 'package:carcare_service/features/feedback/domain/feedback.dart';
import 'package:carcare_service/features/feedback/domain/feedback_repository.dart';
import 'package:dio/dio.dart';

/// Remote adapter for [FeedbackRepository] — P7-F1. JSON/multipart and Dio
/// stay below the repository contract, matching every other Phase 6/7
/// repository.
class RemoteFeedbackRepository implements FeedbackRepository {
  RemoteFeedbackRepository({FeedbackDataSource? dataSource})
    : _dataSource = dataSource ?? RemoteFeedbackDataSource();

  final FeedbackDataSource _dataSource;

  @override
  Future<Result<PagedResult<Feedback>>> getFeedbackList({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      return Ok(
        FeedbackPageDto.fromJson(
          await _dataSource.list({'page': page, 'pageSize': pageSize}),
        ).value,
      );
    } catch (error) {
      return Err(_error(error, 'Санал хүсэлт ачаалж чадсангүй'));
    }
  }

  @override
  Future<Result<FeedbackDetail>> getFeedback(String id) async {
    try {
      return Ok(
        FeedbackDetailDto.fromJson(await _dataSource.detail(id)).value,
      );
    } catch (error) {
      return Err(_error(error, 'Санал хүсэлтийн дэлгэрэнгүй ачаалж чадсангүй'));
    }
  }

  @override
  Future<Result<Feedback>> createFeedback({
    required FeedbackType type,
    required String message,
    String? screenshotPath,
  }) async {
    try {
      final formData = FormData.fromMap({
        'type': type.wire,
        'message': message,
        if (screenshotPath != null && screenshotPath.isNotEmpty)
          'screenshot': await MultipartFile.fromFile(screenshotPath),
      });
      return Ok(FeedbackDto.fromJson(await _dataSource.create(formData)).value);
    } catch (error) {
      return Err(_error(error, 'Санал хүсэлт илгээж чадсангүй'));
    }
  }

  @override
  Future<Result<FeedbackReplyResult>> reply(
    String id, {
    required String message,
  }) async {
    try {
      return Ok(
        FeedbackReplyResultDto.fromJson(
          await _dataSource.reply(id, {'message': message}),
        ).value,
      );
    } catch (error) {
      return Err(_error(error, 'Хариу илгээж чадсангүй'));
    }
  }
}

AppError _error(Object error, String fallback) => switch (error) {
  AppError value => value,
  FeedbackParseException value => AppError(ErrorKind.unknown, value.message),
  _ => AppError(ErrorKind.unknown, fallback),
};
