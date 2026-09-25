import 'package:image_picker/image_picker.dart';

/// Server upload limit per file (`carcare.mn` `lib/storage.ts` MAX_BYTES).
/// One oversized photo rejects the whole multipart request, so check before
/// sending instead of failing the entire report after the upload.
const uploadMaxBytes = 2 * 1024 * 1024;

/// Downscale camera photos before upload: a full-resolution 12MP JPEG is
/// routinely above [uploadMaxBytes] even at quality 70.
const uploadMaxDimension = 1920.0;
const uploadImageQuality = 70;

const uploadTooLargeMessage =
    'Зураг 2MB-аас том байна. Жижиг зураг сонгоно уу.';

/// Splits picked images into those within [uploadMaxBytes] and the count of
/// rejected ones.
Future<({List<XFile> accepted, int rejected})> filterUploadable(
  List<XFile> images,
) async {
  final accepted = <XFile>[];
  var rejected = 0;
  for (final image in images) {
    if (await image.length() <= uploadMaxBytes) {
      accepted.add(image);
    } else {
      rejected++;
    }
  }
  return (accepted: accepted, rejected: rejected);
}
