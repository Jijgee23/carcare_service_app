/// Хүлээн авалтын тэмдэглэл (зөвхөн захиалга үүсгэх үед бичигдэнэ, дараа нь
/// засагдахгүй).
class OrderIntakePhoto {
  const OrderIntakePhoto({required this.id, required this.url});

  final String id;

  /// Серверийн харьцангуй зам (`/uploads/...`).
  final String url;
}

class OrderIntake {
  const OrderIntake({
    this.notes,
    this.photos = const [],
    this.signatureUrl,
    required this.recordedAt,
    this.recordedBy,
  });

  final String? notes;
  final List<OrderIntakePhoto> photos;
  final String? signatureUrl;
  final DateTime recordedAt;
  final String? recordedBy;
}

/// Захиалга үүсгэхэд илгээх хүлээн авалтын ноорог.
class OrderIntakeDraft {
  const OrderIntakeDraft({
    this.notes,
    this.photoPaths = const [],
    this.signaturePath,
  });

  final String? notes;
  final List<String> photoPaths;
  final String? signaturePath;

  bool get isEmpty =>
      (notes == null || notes!.trim().isEmpty) &&
      photoPaths.isEmpty &&
      signaturePath == null;

  Map<String, dynamic> toJson() => {
    if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
    if (photoPaths.isNotEmpty) 'photoPaths': photoPaths,
    if (signaturePath != null) 'signaturePath': signaturePath,
  };
}
