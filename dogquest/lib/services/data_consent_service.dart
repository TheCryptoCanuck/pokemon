import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';

final _log = Logger('DataConsentService');

/// Manages user consent for aggregated data sharing (B2B/research).
///
/// Consent is opt-in. When enabled, sighting data (species, GPS, timestamp,
/// confidence) may be shared in de-identified form with conservation
/// organizations, researchers, and environmental consultants.
class DataConsentService {
  static const _boxName = 'dogquest_player_stats';
  static const _consentKey = 'data_sharing_consent';
  static const _consentDateKey = 'data_sharing_consent_date';
  static const _promptShownKey = 'data_sharing_prompt_shown';

  /// Whether the user has opted in to aggregated data sharing.
  static bool get hasConsented {
    final box = Hive.box(_boxName);
    return box.get(_consentKey, defaultValue: false) as bool;
  }

  /// When the user last changed their consent (ISO 8601).
  static String? get consentDate {
    final box = Hive.box(_boxName);
    return box.get(_consentDateKey) as String?;
  }

  /// Whether we've already shown the one-time consent prompt.
  static bool get promptShown {
    final box = Hive.box(_boxName);
    return box.get(_promptShownKey, defaultValue: false) as bool;
  }

  /// Set consent and record the timestamp.
  static Future<void> setConsent(bool value) async {
    final box = Hive.box(_boxName);
    await box.put(_consentKey, value);
    await box.put(_consentDateKey, DateTime.now().toIso8601String());
    _log.info('Data sharing consent ${value ? "granted" : "revoked"}');
  }

  /// Mark the one-time prompt as shown.
  static Future<void> markPromptShown() async {
    final box = Hive.box(_boxName);
    await box.put(_promptShownKey, true);
  }
}
