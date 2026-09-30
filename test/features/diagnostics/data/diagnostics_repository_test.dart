import 'package:carservice_business/core/errors/app_error.dart';
import 'package:carservice_business/core/utils/result.dart';
import 'package:carservice_business/features/diagnostics/data/diagnostics_data_source.dart';
import 'package:carservice_business/features/diagnostics/data/diagnostics_repository.dart';
import 'package:carservice_business/features/diagnostics/domain/diagnostic.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Source implements DiagnosticsDataSource {
  Object? response;
  Object? failure;
  String? call;
  Map<String, dynamic>? query;
  Future<T> _run<T>(String name, T Function() get) async {
    call = name;
    if (failure != null) throw failure!;
    return get();
  }

  @override
  Future<Object?> getTemplates({Map<String, dynamic>? query}) {
    this.query = query;
    return _run('getTemplates', () => response);
  }

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

  test(
    'pickers ask for active templates; the management list for all',
    () async {
      final source = _Source()..response = {'templates': []};
      final repo = DiagnosticsRepositoryImpl(source);

      await repo.getTemplates();
      expect(source.query, {'pageSize': 200});

      await repo.getTemplates(includeInactive: true);
      expect(source.query, {'includeInactive': 'true', 'pageSize': 200});
    },
  );

  test('delete reports whether the template was archived', () async {
    final source = _Source();
    final repo = DiagnosticsRepositoryImpl(source);

    source.response = {
      'template': {'id': 't', 'name': 'A', 'outcome': 'archived'},
    };
    expect(
      (await repo.deleteTemplate('t') as Ok<TemplateDeleteOutcome>).value,
      TemplateDeleteOutcome.archived,
    );

    source.response = {
      'template': {'id': 't', 'name': 'A', 'outcome': 'deleted'},
    };
    expect(
      (await repo.deleteTemplate('t') as Ok<TemplateDeleteOutcome>).value,
      TemplateDeleteOutcome.deleted,
    );
  });

  test('list rows read the price string and the web-only extras', () async {
    final source = _Source()
      ..response = {
        'templates': [
          {
            'id': 'a',
            'name': 'Хүлээж авах',
            'type': 'INTAKE',
            'version': 3,
            'isActive': false,
            'price': '25000',
            'durationMin': 30,
          },
          {
            'id': 'b',
            'name': 'Сан',
            'type': 'ROUTINE',
            'tenantId': null,
            'isSystemDefault': false,
            'category': {'name': 'Оношилгоо'},
            '_count': {'reports': 4},
          },
        ],
      };
    final list =
        (await DiagnosticsRepositoryImpl(source).getTemplates()
                as Ok<List<DiagnosticTemplateSummary>>)
            .value;

    final a = list[0];
    expect(a.price, 25000);
    expect(a.durationMin, 30);
    expect(a.version, 3);
    expect(a.isActive, isFalse);
    expect(a.categoryName, isNull);
    expect(a.reportCount, isNull);
    expect(a.readOnly, isFalse);

    final b = list[1];
    expect(b.categoryName, 'Оношилгоо');
    expect(b.reportCount, 4);
    expect(b.isShared, isTrue);
    expect(b.readOnly, isTrue);
  });
}
