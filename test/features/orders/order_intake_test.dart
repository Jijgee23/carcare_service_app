import 'dart:typed_data';

import 'package:carservice_business/app/theme/app_theme.dart';
import 'package:carservice_business/core/errors/app_error.dart';
import 'package:carservice_business/core/utils/media_url.dart';
import 'package:carservice_business/core/utils/price_input.dart';
import 'package:carservice_business/core/utils/result.dart';
import 'package:carservice_business/features/orders/data/order_dto.dart';
import 'package:carservice_business/features/orders/data/order_repository.dart';
import 'package:carservice_business/features/orders/data/orders_data_source.dart';
import 'package:carservice_business/features/orders/presentation/controllers/order_intake_controller.dart';
import 'package:carservice_business/features/orders/presentation/widgets/intake/intake_section.dart';
import 'package:carservice_business/features/orders/presentation/widgets/intake/order_intake_view.dart';
import 'package:carservice_business/features/orders/presentation/widgets/intake/signature_pad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../fakes/fake_order_repository.dart';

Map<String, dynamic> _orderJson({Object? intake}) => {
  'id': 'order-1',
  'number': 'D1-1001',
  'status': 'SCHEDULED',
  'paymentStatus': 'UNPAID',
  'scheduledAt': null,
  'startedAt': null,
  'completedAt': null,
  'totalAmount': '0.00',
  'paidAmount': '0.00',
  'notes': null,
  'createdAt': '2026-09-18T03:00:00.000Z',
  'customer': {'id': 'c1', 'fullName': 'Бат', 'phone': '99001122'},
  'vehicle': {'id': 'v1', 'plate': '1234ABC', 'make': 'T', 'model': 'P'},
  'branch': {'id': 'b1', 'name': 'Толгойт'},
  'assignedTo': null,
  'items': [],
  'reports': [],
  'intake': intake,
};

/// Records the create body and upload arguments; everything else unused.
class _Source implements OrdersDataSource {
  Map<String, dynamic>? createBody;
  String? uploadFilename;
  String? uploadMime;
  Object? uploadResponse = {'url': '/uploads/a.png', 'size': 1, 'mime': 'x'};

  @override
  Future<Object?> create(Map<String, dynamic> body) async {
    createBody = body;
    return {'order': _orderJson()};
  }

  @override
  Future<Object?> uploadIntake(
    Uint8List bytes,
    String filename,
    String mime,
  ) async {
    uploadFilename = filename;
    uploadMime = mime;
    return uploadResponse;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpApp(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    GetMaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pump();
}

void main() {
  group('OrderDetailDto intake', () {
    test('parses intake block', () {
      final dto = OrderDetailDto.fromJson({
        'order': _orderJson(
          intake: {
            'notes': 'Зураас байна',
            'photos': [
              {'id': 'p1', 'url': '/uploads/p1.jpg'},
            ],
            'signatureUrl': '/uploads/s.png',
            'recordedAt': '2026-10-02T03:00:00.000Z',
            'recordedBy': 'Бат Дорж',
          },
        ),
      });
      final intake = dto.value.intake!;
      expect(intake.notes, 'Зураас байна');
      expect(intake.photos.single.url, '/uploads/p1.jpg');
      expect(intake.signatureUrl, '/uploads/s.png');
      expect(intake.recordedBy, 'Бат Дорж');
    });

    test('null intake stays null', () {
      expect(
        OrderDetailDto.fromJson({'order': _orderJson()}).value.intake,
        isNull,
      );
    });

    test('malformed intake becomes null instead of failing the order', () {
      final dto = OrderDetailDto.fromJson({
        'order': _orderJson(intake: {'photos': []}),
      });
      expect(dto.value.intake, isNull);
      expect(dto.value.id, 'order-1');
      expect(
        OrderDetailDto.fromJson({'order': _orderJson(intake: 'oops')})
            .value
            .intake,
        isNull,
      );
    });

    test('skips malformed photo entries and keeps the rest', () {
      final dto = OrderDetailDto.fromJson({
        'order': _orderJson(
          intake: {
            'notes': null,
            'photos': [
              {'id': 'p1', 'url': '/uploads/p1.jpg'},
              {'id': 'p2'},
              'bad',
              {'id': 'p3', 'url': '/uploads/p3.jpg'},
            ],
            'signatureUrl': null,
            'recordedAt': '2026-10-02T03:00:00.000Z',
            'recordedBy': null,
          },
        ),
      });
      expect(dto.value.intake!.photos.map((p) => p.id), ['p1', 'p3']);
    });
  });

  group('RemoteOrdersRepository intake', () {
    test('createOrder sends intake object', () async {
      final source = _Source();
      final repo = RemoteOrdersRepository(dataSource: source);
      await repo.createOrder(
        branchId: 'b1',
        customerId: 'c1',
        vehicleId: 'v1',
        intake: const OrderIntakeDraft(
          notes: '  тэмдэглэл ',
          photoPaths: ['/uploads/a.png'],
          signaturePath: '/uploads/s.png',
        ),
      );
      expect(source.createBody!['intake'], {
        'notes': 'тэмдэглэл',
        'photoPaths': ['/uploads/a.png'],
        'signaturePath': '/uploads/s.png',
      });
    });

    test('createOrder omits empty or null intake', () async {
      final source = _Source();
      final repo = RemoteOrdersRepository(dataSource: source);
      await repo.createOrder(
        branchId: 'b1',
        customerId: 'c1',
        vehicleId: 'v1',
        intake: const OrderIntakeDraft(notes: '  '),
      );
      expect(source.createBody!.containsKey('intake'), isFalse);
    });

    test('uploadIntakeFile returns url, signature uses image/png', () async {
      final source = _Source();
      final repo = RemoteOrdersRepository(dataSource: source);
      final r = await repo.uploadIntakeFile(
        Uint8List(1),
        'signature.png',
        signature: true,
      );
      expect((r as Ok<String>).value, '/uploads/a.png');
      expect(source.uploadMime, 'image/png');
      await repo.uploadIntakeFile(Uint8List(1), 'x.JPG', signature: false);
      expect(source.uploadMime, 'image/jpeg');
    });

    test('uploadIntakeFile errors on missing url', () async {
      final source = _Source()..uploadResponse = {'size': 1};
      final repo = RemoteOrdersRepository(dataSource: source);
      final r = await repo.uploadIntakeFile(
        Uint8List(1),
        'x.png',
        signature: false,
      );
      expect(r, isA<Err<String>>());
    });
  });

  group('OrderIntakeController', () {
    test('uploads photos, caps at 20, builds draft', () async {
      final repo = FakeOrderRepository();
      final c = OrderIntakeController(repo);
      final dropped = await c.addPhotos([
        for (var i = 0; i < 22; i++) (filename: 'p$i.jpg', bytes: Uint8List(1)),
      ]);
      expect(dropped, 2);
      expect(c.photos.length, 20);
      expect(c.uploading, isFalse);
      c.notesCtrl.text = 'abc';
      expect(c.draft!.photoPaths.length, 20);
      expect(c.draft!.notes, 'abc');
      c.dispose();
    });

    test('failed upload is excluded from draft and retryable', () async {
      final repo = FakeOrderRepository()
        ..uploadIntakeFailure = const AppError(ErrorKind.server, 'x');
      final c = OrderIntakeController(repo);
      await c.addPhotos([(filename: 'a.jpg', bytes: Uint8List(1))]);
      expect(c.hasFailedPhoto, isTrue);
      expect(c.draft, isNull);
      repo.uploadIntakeFailure = null;
      await c.retryPhoto(c.photos.single);
      expect(c.draft!.photoPaths, hasLength(1));
      c.dispose();
    });

    test('empty controller has no draft; signature sets path', () async {
      final c = OrderIntakeController(FakeOrderRepository());
      expect(c.draft, isNull);
      expect(await c.saveSignature(Uint8List(2)), isTrue);
      expect(c.draft!.signaturePath, isNotNull);
      c.clearSignature();
      expect(c.draft, isNull);
      c.dispose();
    });
  });

  group('submit blockers', () {
    test('failed photo blocks with a reason, removal clears it', () async {
      final repo = FakeOrderRepository()
        ..uploadIntakeFailure = const AppError(ErrorKind.server, 'x');
      final c = OrderIntakeController(repo);
      await c.addPhotos([(filename: 'a.jpg', bytes: Uint8List(1))]);
      expect(c.blockReason, contains('амжилтгүй'));
      c.removePhoto(c.photos.single);
      expect(c.blockReason, isNull);
      c.dispose();
    });

    test('unsaved signature blocks until saved or cleared', () async {
      final c = OrderIntakeController(FakeOrderRepository());
      c.setSignatureDirty(true);
      expect(c.blockReason, 'Гарын үсгээ хадгална уу эсвэл арилгана уу');
      await c.saveSignature(Uint8List(2));
      expect(c.blockReason, isNull);
      c.dispose();
    });
  });

  group('widgets', () {
    testWidgets('dragging the pad draws and does not scroll the form', (
      tester,
    ) async {
      final c = OrderIntakeController(FakeOrderRepository());
      final scroll = ScrollController();
      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scroll,
              child: Column(
                children: [
                  IntakeSection(controller: c),
                  const SizedBox(height: 1500),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('intake_toggle')));
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const ValueKey('intake_signature_start')),
      );
      await tester.tap(find.byKey(const ValueKey('intake_signature_start')));
      await tester.pump();
      final pad = find.byType(SignaturePad);
      await tester.ensureVisible(pad);
      await tester.pump();
      final before = scroll.offset;
      final g = await tester.startGesture(tester.getCenter(pad));
      await g.moveBy(const Offset(0, -60));
      await g.moveBy(const Offset(0, -40));
      await g.up();
      await tester.pump();
      expect(scroll.offset, before);
      expect(c.signatureDirty, isTrue);
      expect(find.byKey(const ValueKey('intake_block_reason')), findsOneWidget);
      c.dispose();
    });

    test('exportSignaturePng is null when empty', () async {
      expect(await exportSignaturePng([], const Size(10, 10)), isNull);
    });

    testWidgets('section toggles open and closed', (tester) async {
      final c = OrderIntakeController(FakeOrderRepository());
      await _pumpApp(tester, IntakeSection(controller: c));
      expect(find.byKey(const ValueKey('intake_notes')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('intake_toggle')));
      await tester.pump();
      expect(find.byKey(const ValueKey('intake_notes')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('intake_signature_start')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('intake_toggle')));
      await tester.pump();
      expect(find.byKey(const ValueKey('intake_notes')), findsNothing);
      c.dispose();
    });

    testWidgets('detail tile hidden when intake null', (tester) async {
      await _pumpApp(tester, const OrderIntakeTile(intake: null));
      expect(
        find.byKey(const ValueKey('order_detail_intake_tile')),
        findsNothing,
      );
    });

    testWidgets('detail tile opens read-only page', (tester) async {
      final intake = OrderIntake(
        notes: 'Хуучин зураас',
        photos: const [OrderIntakePhoto(id: 'p', url: '/uploads/p.jpg')],
        recordedAt: DateTime(2026, 10, 2, 9, 30),
        recordedBy: 'Бат Дорж',
      );
      await _pumpApp(tester, OrderIntakeTile(intake: intake));
      await tester.tap(find.byKey(const ValueKey('order_detail_intake_tile')));
      await tester.pumpAndSettle();
      expect(find.text('Хуучин зураас'), findsOneWidget);
      expect(find.text('Бүртгэсэн: Бат Дорж'), findsOneWidget);
      expect(find.byKey(const ValueKey('intake_photo_pager')), findsOneWidget);
    });
  });

  group('intake mileage', () {
    test('integer formatter groups digits and drops the rest', () {
      expect(liveFormatIntegerInput('152300'), '152,300');
      expect(liveFormatIntegerInput('1,5a2.3'), '1,523');
      expect(liveFormatIntegerInput('007'), '7');
      expect(liveFormatIntegerInput('0'), '0');
      expect(liveFormatIntegerInput(''), '');
      expect(liveFormatIntegerInput('2000000'), '2,000,000');
      expect(parseIntegerInput('152,300'), 152300);
      expect(parseIntegerInput(''), isNull);
    });

    testWidgets('field groups as you type and feeds the draft', (tester) async {
      final c = OrderIntakeController(FakeOrderRepository());
      await _pumpApp(tester, IntakeSection(controller: c));
      await tester.tap(find.byKey(const ValueKey('intake_toggle')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('intake_mileage')),
        '152300',
      );
      await tester.pump();
      expect(c.mileageCtrl.text, '152,300');
      expect(c.mileageKm, 152300);
      expect(c.draft!.mileageKm, 152300);
      expect(c.blockReason, isNull);
      c.dispose();
    });

    test('mileage alone makes the draft non-empty; zero counts', () {
      final c = OrderIntakeController(FakeOrderRepository());
      expect(c.isEmpty, isTrue);
      c.mileageCtrl.text = '0';
      expect(c.isEmpty, isFalse);
      expect(c.draft!.toJson(), {'mileageKm': 0});
      c.dispose();
    });

    test('out of range blocks submit with the inline error', () {
      final c = OrderIntakeController(FakeOrderRepository());
      c.mileageCtrl.text = '2,000,001';
      expect(c.mileageErrorText, 'Гүйлт 0–2,000,000 км байх ёстой.');
      expect(c.blockReason, 'Гүйлт 0–2,000,000 км байх ёстой.');
      expect(c.draft, isNull);
      c.mileageCtrl.text = '2,000,000';
      expect(c.mileageErrorText, isNull);
      expect(c.blockReason, isNull);
      c.dispose();
    });

    test(
      'createOrder sends mileageKm as a plain integer; omits when empty',
      () async {
        final source = _Source();
        final repo = RemoteOrdersRepository(dataSource: source);
        await repo.createOrder(
          branchId: 'b1',
          customerId: 'c1',
          vehicleId: 'v1',
          intake: const OrderIntakeDraft(mileageKm: 152300),
        );
        expect(source.createBody!['intake'], {'mileageKm': 152300});
        await repo.createOrder(
          branchId: 'b1',
          customerId: 'c1',
          vehicleId: 'v1',
          intake: const OrderIntakeDraft(notes: 'x'),
        );
        expect(source.createBody!['intake'], {'notes': 'x'});
      },
    );

    test('detail DTO parses mileageKm, tolerant of junk', () {
      OrderIntake? parse(Object? km) => OrderDetailDto.fromJson({
        'order': _orderJson(
          intake: {
            'photos': [],
            'recordedAt': '2026-10-02T03:00:00.000Z',
            'mileageKm': km,
          },
        ),
      }).value.intake;
      expect(parse(152300)!.mileageKm, 152300);
      expect(parse(null)!.mileageKm, isNull);
      expect(parse('x')!.mileageKm, isNull);
    });

    testWidgets('detail tile and page show the mileage', (tester) async {
      final intake = OrderIntake(
        recordedAt: DateTime(2026, 10, 2, 9, 30),
        mileageKm: 152300,
      );
      await _pumpApp(tester, OrderIntakeTile(intake: intake));
      expect(find.textContaining('152,300 км'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('order_detail_intake_tile')));
      await tester.pumpAndSettle();
      expect(find.text('Гүйлт: 152,300 км'), findsOneWidget);
    });
  });

  test('resolveMediaUrl joins relative paths onto the API origin', () {
    const base = 'https://api.example.test/api/v1/';
    expect(
      resolveMediaUrl('/uploads/a.png', baseUrl: base),
      'https://api.example.test/uploads/a.png',
    );
    expect(
      resolveMediaUrl('https://cdn.test/a.png', baseUrl: base),
      'https://cdn.test/a.png',
    );
  });
}
