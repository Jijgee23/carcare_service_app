import 'dart:typed_data';

import 'package:carservice_business/core/utils/price_input.dart';
import 'package:carservice_business/core/utils/result.dart';
import 'package:carservice_business/features/orders/domain/order_intake.dart';
import 'package:carservice_business/features/orders/domain/orders_repository.dart';
import 'package:flutter/widgets.dart';

enum IntakeUploadStatus { uploading, done, failed }

class IntakePhotoItem {
  IntakePhotoItem({required this.filename, required this.bytes});

  final String filename;
  final Uint8List bytes;
  IntakeUploadStatus status = IntakeUploadStatus.uploading;

  /// Сервер дээрх түр зам (upload амжилттай болсны дараа).
  String? url;
}

/// Захиалга үүсгэх дэлгэцийн «Хүлээн авах» хэсгийн төлөв.
/// Зураг бүр сонгогдмогц шууд upload хийгдэнэ; submit нь [uploading] үед
/// хаалттай.
class OrderIntakeController extends ChangeNotifier {
  OrderIntakeController(this._repository) {
    mileageCtrl.addListener(_notify);
  }

  static const maxMileageKm = 2000000;
  static const mileageError = 'Гүйлт 0–2,000,000 км байх ёстой.';
  static const maxPhotos = 20;
  static const maxNotes = 5000;

  final OrdersRepository _repository;
  final notesCtrl = TextEditingController();
  final mileageCtrl = TextEditingController();
  final List<IntakePhotoItem> photos = [];

  Uint8List? signatureBytes;
  String? signatureUrl;
  bool signatureUploading = false;
  String? signatureError;
  bool _disposed = false;

  /// Гарын үсгийн талбарт хадгалаагүй зураас байгаа эсэх.
  bool signatureDirty = false;

  void setSignatureDirty(bool value) {
    if (signatureDirty == value) return;
    signatureDirty = value;
    _notify();
  }

  /// Оруулсан гүйлт (км); хоосон эсвэл хүрээнээс гарсан бол `null`.
  int? get mileageKm {
    final km = parseIntegerInput(mileageCtrl.text);
    return km != null && km >= 0 && km <= maxMileageKm ? km : null;
  }

  /// Гүйлт оруулсан боловч буруу (хүрээнээс гарсан) үед алдааны текст.
  String? get mileageErrorText {
    if (mileageCtrl.text.trim().isEmpty) return null;
    return mileageKm == null ? mileageError : null;
  }

  /// Submit-ийг хаах шалтгаан (байхгүй бол `null`). Upload дуусаагүй,
  /// амжилтгүй зураг, хадгалаагүй гарын үсэг гурвыг ялгана.
  String? get blockReason {
    if (mileageErrorText != null) return mileageErrorText;
    if (uploading) return 'Файл хуулж байна...';
    if (hasFailedPhoto) {
      return 'Зураг upload амжилтгүй — дахин оролдох эсвэл устгана уу';
    }
    if (signatureDirty) return 'Гарын үсгээ хадгална уу эсвэл арилгана уу';
    return null;
  }

  int get remainingPhotoSlots => maxPhotos - photos.length;

  bool get uploading =>
      signatureUploading ||
      photos.any((p) => p.status == IntakeUploadStatus.uploading);

  bool get hasFailedPhoto =>
      photos.any((p) => p.status == IntakeUploadStatus.failed);

  bool get isEmpty => draft == null;

  /// Серверт илгээх ноорог; хоосон бол `null`.
  OrderIntakeDraft? get draft {
    final value = OrderIntakeDraft(
      notes: notesCtrl.text,
      photoPaths: [
        for (final p in photos)
          if (p.status == IntakeUploadStatus.done && p.url != null) p.url!,
      ],
      signaturePath: signatureUrl,
      mileageKm: mileageKm,
    );
    return value.isEmpty ? null : value;
  }

  /// Сонгосон зургуудыг (cap 20 хүртэл) нэмж, тус бүрийг upload хийнэ.
  /// Cap-аас хэтэрсэн тоог буцаана.
  Future<int> addPhotos(
    List<({String filename, Uint8List bytes})> files,
  ) async {
    final accepted = files.take(remainingPhotoSlots).toList();
    final dropped = files.length - accepted.length;
    final items = [
      for (final f in accepted)
        IntakePhotoItem(filename: f.filename, bytes: f.bytes),
    ];
    photos.addAll(items);
    _notify();
    await Future.wait(items.map(_upload));
    return dropped;
  }

  Future<void> retryPhoto(IntakePhotoItem item) async {
    item.status = IntakeUploadStatus.uploading;
    _notify();
    await _upload(item);
  }

  Future<void> _upload(IntakePhotoItem item) async {
    final result = await _repository.uploadIntakeFile(
      item.bytes,
      item.filename,
      signature: false,
    );
    if (!photos.contains(item)) return; // upload дундуур устгагдсан
    switch (result) {
      case Ok(:final value):
        item.url = value;
        item.status = IntakeUploadStatus.done;
      case Err():
        item.status = IntakeUploadStatus.failed;
    }
    _notify();
  }

  void removePhoto(IntakePhotoItem item) {
    photos.remove(item);
    _notify();
  }

  /// Гарын үсгийн PNG-г upload хийж хадгална.
  Future<bool> saveSignature(Uint8List png) async {
    signatureUploading = true;
    signatureError = null;
    _notify();
    final result = await _repository.uploadIntakeFile(
      png,
      'signature.png',
      signature: true,
    );
    signatureUploading = false;
    switch (result) {
      case Ok(:final value):
        signatureBytes = png;
        signatureUrl = value;
        signatureDirty = false;
        _notify();
        return true;
      case Err(:final error):
        signatureError = error.display;
        _notify();
        return false;
    }
  }

  void clearSignature() {
    signatureBytes = null;
    signatureUrl = null;
    signatureError = null;
    signatureDirty = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    notesCtrl.dispose();
    mileageCtrl.dispose();
    super.dispose();
  }
}
