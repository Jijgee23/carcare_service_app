import 'dart:io';

import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/feedback/data/feedback_data_source.dart';
import 'package:carcare_service/features/feedback/data/feedback_repository.dart';
import 'package:carcare_service/features/feedback/domain/feedback.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const _pagination = {
  'page': 1,
  'pageSize': 20,
  'total': 0,
  'totalPages': 0,
  'hasPrev': false,
  'hasNext': false,
};

void main() {
  group('request shaping', () {
    test('getFeedbackList sends page/pageSize', () async {
      final ds = _RecordingDataSource({'feedback': <Object>[], 'pagination': _pagination});
      await RemoteFeedbackRepository(dataSource: ds).getFeedbackList(page: 2, pageSize: 10);
      expect(ds.lastListQuery, {'page': 2, 'pageSize': 10});
    });

    test('createFeedback sends type and message without a screenshot field '
        'when no path is given', () async {
      final ds = _RecordingDataSource({
        'feedback': {'id': 'f-1', 'type': 'BUG'},
      });
      await RemoteFeedbackRepository(dataSource: ds).createFeedback(
        type: FeedbackType.bug,
        message: 'Алдаа гарлаа',
      );
      final fields = Map.fromEntries(ds.lastCreateFormData!.fields);
      expect(fields['type'], 'BUG');
      expect(fields['message'], 'Алдаа гарлаа');
      expect(ds.lastCreateFormData!.files, isEmpty);
    });

    test('createFeedback attaches the screenshot file when a path is given', () async {
      final tmp = await File(
        '${Directory.systemTemp.path}/feedback_test_${DateTime.now().microsecondsSinceEpoch}.png',
      ).create();
      await tmp.writeAsBytes([1, 2, 3]);
      addTearDown(() => tmp.delete());

      final ds = _RecordingDataSource({
        'feedback': {'id': 'f-1', 'type': 'BUG'},
      });
      await RemoteFeedbackRepository(dataSource: ds).createFeedback(
        type: FeedbackType.bug,
        message: 'Зурагтай алдаа',
        screenshotPath: tmp.path,
      );
      expect(ds.lastCreateFormData!.files, hasLength(1));
      expect(ds.lastCreateFormData!.files.single.key, 'screenshot');
    });

    test('reply sends the trimmed-by-caller message body verbatim', () async {
      final ds = _RecordingDataSource({
        'message': {'id': 'm-1', 'author': 'SUBMITTER'},
        'reopened': false,
      });
      await RemoteFeedbackRepository(dataSource: ds).reply('f-1', message: 'Сайн байна уу');
      expect(ds.lastReplyId, 'f-1');
      expect(ds.lastReplyBody, {'message': 'Сайн байна уу'});
    });
  });

  group('response handling', () {
    test('getFeedback unwraps feedback and messages', () async {
      final ds = _RecordingDataSource({
        'feedback': {'id': 'f-1', 'type': 'BUG'},
        'messages': <Object>[],
      });
      final result = await RemoteFeedbackRepository(dataSource: ds).getFeedback('f-1');
      expect((result as Ok).value.feedback.id, 'f-1');
    });

    test('a parse failure becomes Err, never a thrown exception', () async {
      final result = await RemoteFeedbackRepository(
        dataSource: _RecordingDataSource({'wrong': 'envelope'}),
      ).getFeedback('f-1');
      expect(result, isA<Err>());
      expect((result as Err).error.kind, ErrorKind.unknown);
    });

    test('a 404 NOT_FOUND on detail passes through', () async {
      const mapped = AppError(ErrorKind.notFound, 'Олдсонгүй', statusCode: 404, code: 'NOT_FOUND');
      final result = await RemoteFeedbackRepository(
        dataSource: _ThrowingDataSource(mapped),
      ).getFeedback('f-1');
      expect((result as Err).error.code, 'NOT_FOUND');
    });

    test('a 422 VALIDATION on create passes through', () async {
      const mapped = AppError(ErrorKind.unknown, 'Мессеж 5-2000 тэмдэгт байх ёстой.', statusCode: 422, code: 'VALIDATION');
      final result = await RemoteFeedbackRepository(
        dataSource: _ThrowingDataSource(mapped),
      ).createFeedback(type: FeedbackType.bug, message: 'ok');
      expect((result as Err).error.code, 'VALIDATION');
    });
  });
}

class _RecordingDataSource implements FeedbackDataSource {
  _RecordingDataSource(this.payload);
  final Object? payload;
  Map<String, dynamic>? lastListQuery;
  FormData? lastCreateFormData;
  String? lastReplyId;
  Map<String, dynamic>? lastReplyBody;

  @override
  Future<Object?> list(Map<String, dynamic> query) async {
    lastListQuery = query;
    return payload;
  }

  @override
  Future<Object?> detail(String id) async => payload;

  @override
  Future<Object?> create(FormData formData) async {
    lastCreateFormData = formData;
    return payload;
  }

  @override
  Future<Object?> reply(String id, Map<String, dynamic> body) async {
    lastReplyId = id;
    lastReplyBody = body;
    return payload;
  }
}

class _ThrowingDataSource implements FeedbackDataSource {
  _ThrowingDataSource(this.error);
  final AppError error;

  @override
  Future<Object?> list(Map<String, dynamic> query) async => throw error;

  @override
  Future<Object?> detail(String id) async => throw error;

  @override
  Future<Object?> create(FormData formData) async => throw error;

  @override
  Future<Object?> reply(String id, Map<String, dynamic> body) async => throw error;
}
