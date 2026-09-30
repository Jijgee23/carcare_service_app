import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Whether each user on this device accepted the current Үйлчилгээний нөхцөл
/// and Нууцлалын бодлого. Local only, in its own `legal_consent` box, keyed
/// by user id; kept across logout so the same user is asked once per
/// [currentVersion].
///
/// The router listens to this and holds a signed-in user on the consent page
/// until [accept]. Storage is best-effort like the saved login: if a write
/// fails the acceptance still holds for this run, so nobody gets stuck.
class LegalConsentStore extends ChangeNotifier {
  LegalConsentStore._();
  static final instance = LegalConsentStore._();

  /// The terms' effective date. Bump it with `TermsOfServiceScreen
  /// .effectiveDate` to ask every user again.
  static const currentVersion = '2026-09-30';

  static const boxName = 'legal_consent';

  /// Accepted this run, whatever the box managed to store.
  final _acceptedThisRun = <String>{};

  static Future<void> init() async {
    try {
      await Hive.openBox<dynamic>(boxName);
    } catch (_) {
      await Hive.deleteBoxFromDisk(boxName);
      await Hive.openBox<dynamic>(boxName);
    }
  }

  bool hasAccepted(String userId) {
    if (_acceptedThisRun.contains(userId)) return true;
    try {
      final saved = Hive.box<dynamic>(boxName).get(userId);
      return saved is Map && saved['version'] == currentVersion;
    } catch (_) {
      return false;
    }
  }

  Future<void> accept(String userId) async {
    _acceptedThisRun.add(userId);
    notifyListeners();
    try {
      await Hive.box<dynamic>(boxName).put(userId, {
        'version': currentVersion,
        'acceptedAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }
}
