import 'package:carcare_service/core/errors/app_error.dart';
import 'package:carcare_service/core/utils/result.dart';
import 'package:carcare_service/features/diagnostics/data/diagnostics_data_source.dart';
import 'package:carcare_service/features/diagnostics/data/diagnostics_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Source implements DiagnosticsDataSource {
  Object? response;
  Object? failure;
  String? call;
  Future<T> _run<T>(String name, T Function() get) async {
    call = name;
    if (failure != null) throw failure!;
    return get();
  }

  @override
  Future<Object?> getTemplates() => _run('getTemplates', () => response);
  @override
  Future<Object?> getTemplate(String id) => _run('getTemplate', () => response);
  @override
  Future<Object?> createTemplate(Map<String, dynamic> body) =>
      _run('createTemplate', () => response);
  @override
  Future<Object?> updateTemplate(String id, Map<String, dynamic> body) =>
      _run('updateTemplate', () => response);
  @override
  Future<Object?> deleteTemplate(String id) =>
      _run('deleteTemplate', () => response);
  @override
  Future<Object?> duplicateTemplate(String id) =>
      _run('duplicateTemplate', () => response);
  @override
  Future<Object?> getReports(Map<String, dynamic> query) =>
      _run('getReports', () => response);
  @override
  Future<Object?> getReport(String id) => _run('getReport', () => response);
  @override
  Future<Object?> createReport(FormData formData) =>
      _run('createReport', () => response);
  @override
  Future<Object?> deleteReport(String id) =>
      _run('deleteReport', () => response);
  @override
  Future<List<int>> getPdfBytes(String id) => _run(
    'getPdfBytes',
    () => response is List<int>
        ? response as List<int>
        : throw const AppError(ErrorKind.unknown, 'Malformed PDF response'),
  );
}

void main() {
  test(
    'repository methods reach their data source and map HTTP errors',
    () async {
      final source = _Source()..response = {'templates': []};
      final repo = DiagnosticsRepositoryImpl(source);
      final actions = <Future<Result<Object?>> Function()>[
        () async => repo.getTemplates(),
        () async => repo.getTemplate('t'),
        () async => repo.createTemplate(const {}),
        () async => repo.updateTemplate('t', const {}),
        () async => repo.deleteTemplate('t'),
        () async => repo.duplicateTemplate('t'),
        () async => repo.getReports(),
        () async => repo.getReport('r'),
        () async => repo.createReport(FormData()),
        () async => repo.deleteReport('r'),
        () async => repo.getPdfBytes('r'),
      ];
      final calls = [
        'getTemplates',
        'getTemplate',
        'createTemplate',
        'updateTemplate',
        'deleteTemplate',
        'duplicateTemplate',
        'getReports',
        'getReport',
        'createReport',
        'deleteReport',
        'getPdfBytes',
      ];
      for (var i = 0; i < actions.length; i++) {
        source.response = switch (calls[i]) {
          'getTemplates' => {'templates': []},
          'getTemplate' => {
            'template': {'id': 't', 'schema': {}},
          },
          'getReport' => {
            'report': {
              'id': 'r',
              'template': {'id': 't', 'schema': {}},
            },
          },
          'getReports' => {'reports': [], 'pagination': {}},
          'createTemplate' || 'updateTemplate' || 'duplicateTemplate' => {
            'template': {'id': 't'},
          },
          'createReport' => {
            'report': {'id': 'r'},
          },
          'getPdfBytes' => <int>[],
          _ => <String, Object?>{},
        };
        source.failure = const AppError(ErrorKind.forbidden, 'denied');
        final failed = await actions[i]();
        expect(failed, isA<Err<Object?>>(), reason: calls[i]);
        expect(
          (failed as Err).error.kind,
          ErrorKind.forbidden,
          reason: calls[i],
        );
        source.failure = null;
        final success = await actions[i]();
        expect(success, isA<Ok<Object?>>(), reason: calls[i]);
        expect(source.call, calls[i]);
      }
    },
  );

  test(
    'PDF source failure maps to an error instead of empty success',
    () async {
      final source = _Source()..response = 'not bytes';
      final result = await DiagnosticsRepositoryImpl(source).getPdfBytes('r1');
      expect(result, isA<Err<List<int>>>());
      expect((result as Err<List<int>>).error.kind, ErrorKind.unknown);
    },
  );
}
