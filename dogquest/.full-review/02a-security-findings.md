# Phase 2A — Security Findings

**Review date**: 2026-04-26 (post 13-commit landing from 2026-04-25)
**Mode**: strict, security-focus
**Scope**: Flutter app (`lib/`), auth flows, Supabase integration, PII handling, crypto/secrets, input validation, Android manifest, dependencies
**GDPR jurisdiction**: Berlin (from CLAUDE.md). Pre-public-launch checklist applies.

---

## Posture

DogQuest maintains a **solid security baseline** for a pre-closed-beta game with local-first architecture. Supabase RLS is correctly wired per the C1 fix (2026-04-25); hardcoded credentials default to Supabase's public-by-design anonymous key; Hive encryption uses cryptographically sound key storage; EXIF/GPS stripping on photos is implemented; auth state management redirects cleanly. The audit surfaces **2 Critical findings** (both GDPR-specific to Lost Dog), **5 High**, **4 Medium**, **2 Low** — none representing active auth/sync/crypto breaks, but 2 directly blocking Play Store / public launch. Offline auth gate properly invalidated (C1 close verified), SightingSyncService remains dormant (C2), FastAPI backend removed (C3). Pre-beta with 5-10 friends/family is defensible with current posture; public listing requires GDPR remediation.

---

## Findings

### Critical

#### SEC-C-Lost-1: Contact Info Plaintext Broadcast in Lost Dog RPC

**Severity**: CRITICAL (CWE-200: Exposure of Sensitive Information; CWE-352: Cross-Site Request Forgery / PII in Broadcast)  
**CVSS**: 7.5 (High availability / integrity; phone numbers + emails leaked)  
**GDPR**: Article 6 (lawful basis), Article 5 (data minimization), Article 32 (integrity/confidentiality)  
**Location**: `lib/services/supabase_lost_dog_service.dart:220-240` (RPC `get_active_lost_dogs`); spec `docs/session_2026-04-26/lost_dog_improvements_spec.md:44-46`

**The issue**: The `getActiveNearby()` RPC returns full `contact_info` (phone + email) to **any authenticated user** within radius, without a "request contact" intermediary step. This enables:
1. **Scraping**: Attacker crawls all lost dogs, harvests PII for sale or spam.
2. **Stalking**: Victim reports lost dog; attacker now has phone number and GPS coordinates.
3. **GDPR violation**: No lawful basis documented (Article 6), no consent request, no DPA with Supabase.

**Attack scenario**: User reports lost dog near Berlin. Within minutes, an attacker using the app harvests their phone number and exact last-seen location. No phone call, no consent, no opt-out.

**Remediation**: 
**Option A (Minimal, 2-3 hours)**: Strip `contact_info` from RPC return; add "Request contact" workflow:
```sql
-- Server-side RPC change (Supabase)
-- Return only report ID, not contact_info
SELECT id, dog_name, breed, photo_url, last_seen_lat, last_seen_lon, distance_miles, ...
FROM lost_dog_reports WHERE ...
-- Client side: user taps "Request contact" → creates a `contact_requests` table entry
```

**Option B (Recommended, 3-5 hours)**: Add consent + rate limiting + audit logging:
```sql
-- New table: contact_requests
CREATE TABLE contact_requests (
  id UUID PRIMARY KEY,
  report_id UUID REFERENCES lost_dog_reports,
  requester_id UUID REFERENCES auth.users,
  status TEXT ('pending' | 'approved' | 'rejected'),
  created_at TIMESTAMPTZ DEFAULT now(),
  resolved_at TIMESTAMPTZ
);

-- RPC: request_contact(report_id) — creates request; notifies report owner via email
-- RPC: reveal_contact(request_id, approve: bool) — report owner approves, PII revealed

-- Client-side: after request, show "Waiting for owner's approval" UI
```

**Timeline**: **Hard gate for public Play Store launch.** Closed-beta friends-only acceptable if you document informed consent (e.g., Discord message: "FYI — phone numbers are visible to anyone in the app within radius").

**Effort**: Option A 2-3 hr; Option B 3-5 hr.

---

#### SEC-C-Lost-2: No Lawful Basis, Consent Plumbing, or DPA

**Severity**: CRITICAL (CWE-200: Exposure of Sensitive Information; GDPR administrative fine up to €10M / 4% revenue)  
**GDPR**: Article 6 (lawful basis), Article 7 (consent mechanics), Article 28 (processor agreement with Supabase), Article 30 (records of processing)  
**Location**: Entire Lost Dog feature; no privacy policy, no consent dialog, no DPA reference in code

**The issue**:
1. **No privacy policy**: The app has no public privacy policy documenting what PII is collected, stored, and shared. GDPR Article 13/14 requires this before any processing.
2. **No explicit consent request**: Before uploading a lost dog report (which includes exact GPS, dog photo, contact info, breed), the app should show a consent dialog explaining data use. Currently absent.
3. **No DPA with Supabase**: Supabase (a "data processor") must have a signed Data Processing Agreement with you (the "controller"). This is likely missing or not documented.
4. **No retention/deletion policy**: Reports accumulate forever. No expiration, no user-requested deletion, no DPIA (Data Protection Impact Assessment).
5. **Play Store blocking risk**: Google Play Store requires a published privacy policy as a listing condition (App Store Policy 5.2).

**Legal exposure**: €10M fine or 4% of global revenue under GDPR Article 83(4). Play Store suspension until privacy policy + consent wired.

**Remediation** (**Timeline: 8-12 hours including legal review; recommended before any public launch**):

1. **Create privacy policy** (2-3 hr, may need legal review):
   - Publish to a public URL (e.g., `https://dogquest.app/privacy`)
   - Document: data types (PII, location, photos), purposes (lost dog matching), retention (90 days default), rights (user can delete), third-party sharing (Supabase).
   - Add GDPR-specific section: lawful basis (legitimate interest + consent), data subject rights, contact (your email).

2. **Wire consent dialog in app** (1-2 hr):
   ```dart
   // lib/screens/report_lost_screen.dart — before user taps "Report Lost"
   if (!DataConsentService.hasLostDogConsent) {
     showDialog(
       context: context,
       builder: (_) => GDPRConsentDialog(
         title: 'Lost Dog Report Privacy',
         body: '''
           Your report will include:
           - Dog name, breed, photo
           - Your contact info (phone/email)
           - Last seen GPS location (visible to other users within radius)
           
           Data is encrypted and stored by Supabase. Reports expire after 90 days.
           
           See our privacy policy: https://dogquest.app/privacy
         ''',
         onAccept: () async {
           await DataConsentService.setLostDogConsent(true);
           // Proceed with report
         },
       ),
     );
   }
   ```

3. **Sign DPA with Supabase** (email + paperwork, ~1 week):
   - Log into Supabase console → Account → Organization → Documents
   - Download Data Processing Agreement template
   - Sign + return to Supabase; they counter-sign
   - Store PDF in project docs

4. **Document retention policy** (30 min):
   ```dart
   // lib/services/lost_dog_service.dart — add cleanup job
   /// Expire lost dog reports after 90 days (or 30 days if marked as found).
   Future<int> expireOldReports() async {
     final cutoff = DateTime.now().subtract(const Duration(days: 90));
     final reports = await _client
         .from('lost_dog_reports')
         .delete()
         .lt('created_at', cutoff.toIso8601String());
     _log.info('Expired ${reports.count} old lost dog reports');
     return reports.count;
   }
   ```

**Effort**: 8-12 hr total (privacy policy + dialog + DPA + retention job). Blocker for public launch; closed-beta with friends can defer if you send explicit consent email beforehand.

---

### High

#### SEC-H-Lost-1: Permanent Public Photo URLs with No Cleanup

**Severity**: High (CWE-200: Sensitive Information Exposure; CWE-434: Unrestricted Upload)  
**Location**: `lib/services/supabase_lost_dog_service.dart:152-155` (`getPublicUrl()`)

**The issue**: When a user reports a lost dog with a photo, the photo is uploaded to `lost-dog-photos` bucket and assigned a **permanent public URL** via `getPublicUrl()`. If the dog is found, the report is marked as `status='found'`, but **the photo URL never expires or is deleted**.

Implications:
- Found dog's photo remains indexed in search engines indefinitely.
- Attacker screenshots URLs before deletion; can re-share.
- Violates GDPR Article 17 (right to erasure) — user cannot revoke access.

**Remediation** (1-2 hr):
```dart
// lib/services/supabase_lost_dog_service.dart
Future<bool> markFound(String reportId) async {
  try {
    // 1. Fetch the report to get photo_url
    final report = await _client
        .from('lost_dog_reports')
        .select()
        .eq('id', reportId)
        .single();

    final photoUrl = report['photo_url'] as String?;

    // 2. Delete the photo from storage
    if (photoUrl != null) {
      final filename = _extractFilenameFromUrl(photoUrl);
      await _client.storage.from('lost-dog-photos').remove([filename]);
    }

    // 3. Update report status
    await _client.from('lost_dog_reports').update({
      'status': 'found',
      'resolved_at': DateTime.now().toUtc().toIso8601String(),
      'photo_url': null, // Clear the URL
    }).eq('id', reportId);

    _log.info('Marked report $reportId as found; deleted photo');
    return true;
  } catch (e) {
    _log.severe('Failed to mark report as found: $e');
    return false;
  }
}

String _extractFilenameFromUrl(String url) {
  // e.g. 'https://...supabase.co/storage/v1/object/public/lost-dog-photos/lost_dogs/uid/uuid.jpg'
  // Extract: 'lost_dogs/uid/uuid.jpg'
  final uri = Uri.parse(url);
  final parts = uri.pathSegments;
  return parts.skip(parts.length - 3).join('/'); // Last 3 segments
}
```

**Timeline**: Pre-public-launch (nice-to-have for closed-beta if users understand photos persist).

---

#### SEC-H-1: Hardcoded Supabase Credentials in main.dart

**Severity**: High (CWE-798: Use of Hard-coded Credentials; CWE-798 second instance)  
**Location**: `lib/main.dart:100-103`  
**Status**: Pre-existing from Phase 1 Q5 (already flagged, not a regression)

This is a **known-safe false alarm** (Supabase's anonymous key is intentionally public per design; security depends on RLS policies, not key secrecy). However, it **still ships with a default fallback**, which exposes your Supabase project instance to anyone who decompiles the APK.

**Recommendation** (from Phase 1, reiterated):
```dart
// lib/main.dart
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL',
    defaultValue: ''); // Remove default
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY',
    defaultValue: '');

// At startup (in _guardedStartup):
assert(
  _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty,
  'SUPABASE_URL and SUPABASE_ANON_KEY must be provided via --dart-define. '
  'Build with: flutter build apk --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...'
);
```

**Effort**: 15 min. **Timeline**: Pre-public-launch (not urgent for beta).

---

#### SEC-H-2: PII in Auth Logs (Email Broadcast)

**Severity**: High (CWE-532: Insertion of Sensitive Information into Log File)  
**Location**: `lib/services/supabase_auth_service.dart:49, 67, 90`

**The issue**: Auth service logs email addresses in plaintext:
```dart
_log.info('Signed up: $email');  // Line 49
_log.info('Signed in: $email');  // Line 67
_log.info('Password reset email sent to $email');  // Line 90
```

If logs are sent to Sentry (wired in Phase 4), PII is exposed to Sentry's servers. If logs are persisted locally, a malicious app with file-system access can harvest emails.

**Remediation** (1 hr):
```dart
// lib/services/supabase_auth_service.dart
String _redactEmail(String email) {
  final parts = email.split('@');
  if (parts.length != 2) return '***@***';
  final local = parts[0];
  final masked = local.length > 2
    ? local[0] + '*' * (local.length - 2) + local[local.length - 1]
    : '***';
  return '$masked@${parts[1]}';
}

// Replace all three logs:
_log.info('Signed up: ${_redactEmail(email)}');
_log.info('Signed in: ${_redactEmail(email)}');
_log.info('Password reset email sent to ${_redactEmail(email)}');
```

**Timeline**: Pre-Sentry-wiring (Phase 4), so ~2 weeks.

---

#### SEC-H-3: Non-Secure Random in Lost Dog ID Generation

**Severity**: High (CWE-338: Use of Cryptographically Weak Pseudo-Random Number Generator)  
**Location**: `lib/services/lost_dog_service.dart:187-191`

**The issue**:
```dart
String _generateId() {
  final rng = Random();  // ← Uses Dart's default PRNG, not cryptographically secure
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final rand = rng.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0');
  return '$timestamp-$rand';
}
```

This ID generator is **timestamp + 16-bit random suffix**. An attacker can predict the next ID by knowing (or guessing) the current timestamp and bruteforcing 65K possibilities. For Lost Dog reports (which are publicly visible), this allows an attacker to enumerate all reports and trigger bulk downloads.

This is marked sec-C2-adjacent in the archive review; the spec (page 108) flags it: "ID generation in `_generateId()` is timestamp-based (collision-prone, not server-friendly)".

**Remediation** (30 min):
```dart
import 'dart:math';
import 'package:uuid/uuid.dart';

String _generateId() {
  // Use UUID v4 instead (cryptographically secure, universally unique)
  return const Uuid().v4();
}
```

**Timeline**: Pre-public-launch (nice-to-have for closed-beta, but recommended).

---

#### SEC-H-4: Android Manifest Allows Backup + No Network Security Config Verification

**Severity**: High (CWE-200: Exposure of Sensitive Information)  
**Location**: `android/app/src/main/AndroidManifest.xml:16-18`

**The issue**: The manifest sets `android:allowBackup="false"` and `android:fullBackupContent="false"` (good), but references `android:networkSecurityConfig="@xml/network_security_config"`. This file is **not in the audit scope** — if it enables cleartext traffic or disables pinning, TLS could be bypassed.

**Verification needed**: 
1. Read `android/app/src/main/res/xml/network_security_config.xml` (if it exists)
2. Confirm `<domain-config cleartextTrafficPermitted="false">` for all domains
3. Confirm no custom trust anchors that weaken CA validation

**Remediation** (if issues found): 
```xml
<!-- android/app/src/main/res/xml/network_security_config.xml -->
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
  <!-- Disallow cleartext traffic globally -->
  <domain-config cleartextTrafficPermitted="false">
    <domain includeSubdomains="true">supabase.co</domain>
    <domain includeSubdomains="true">googleapis.com</domain>
  </domain-config>
</network-security-config>
```

**Timeline**: Pre-public-launch (needs manual verification).

---

### Medium

#### SEC-M-1: Lost Dog ID Collision Risk + Weak Entropy

**Severity**: Medium (CWE-330: Use of Insufficiently Random Values)  
**Location**: Same as SEC-H-3; appears as a medium (non-critical) issue for timestamp collisions

**The issue**: Two lost dog reports created in the same millisecond could collide if the 16-bit random suffix repeats. Probability is low (~0.0015% per pair) but non-zero.

**Included in SEC-H-3 remediation** (use UUID v4 instead).

---

#### SEC-M-2: Lost Dog Sighting Location Exposed at Full Precision

**Severity**: Medium (CWE-200: Exposure of Sensitive Information)  
**Location**: `lib/services/supabase_lost_dog_service.dart:86-92` (sighting data model)

**The issue**: Lost dog sightings include `latitude` and `longitude` at full floating-point precision (~11 cm accuracy). This allows an attacker to pinpoint exact locations where users have been.

**GDPR concern**: Article 5 (data minimization) — location should not be more precise than necessary. Industry standard is to fuzz to ~500 m (0.005°).

**Remediation** (1-2 hr):
```dart
// lib/services/supabase_lost_dog_service.dart
// Helper function to fuzz GPS coordinates to ~500m precision
static (double, double) fuzzyCoords(double lat, double lon) {
  const fuzzFactor = 0.005; // ~500 m at the equator
  final rng = Random.secure();
  final fuzzedLat = lat + (rng.nextDouble() - 0.5) * fuzzFactor;
  final fuzzedLon = lon + (rng.nextDouble() - 0.5) * fuzzFactor;
  return (fuzzedLat, fuzzedLon);
}

// When returning sightings to non-owner users:
final (displayLat, displayLon) = fuzzyCoords(
  sighting.latitude,
  sighting.longitude,
);
```

**Timeline**: Pre-public-launch (or closed-beta with informed consent).

---

#### SEC-M-3: Supabase RLS Policies Not Audited in This Session

**Severity**: Medium (CWE-639: Authorization Bypass Through User-Controlled Key)  
**Location**: Supabase project (not accessible via code audit)

**The issue**: Phase 1 verified that RLS policies exist (sightings_own, etc.) but did not audit their **correctness**. If an RLS policy is misconfigured (e.g., missing a WHERE clause), the entire app's access control fails.

**What needs verification**:
- `lost_dog_reports` table: Can users read all reports (expected), but can they modify / delete others' reports (should not)?
- `lost_dog_sightings` table: Can a user delete sightings for any report, or only their own?
- `friendships` table: Can a user accept/reject a friendship not intended for them?
- `packs` table: Can a user join a pack via invite code spoofing?

**Verification** (30 min, done manually on Supabase console):
1. Log into [app.supabase.com](https://app.supabase.com) → your project
2. SQL Editor → run test queries with different `auth.uid()` values
3. Confirm each table's RLS policy blocks unauthorized reads/writes

**Timeline**: **Required before public launch**, not for closed-beta.

---

#### SEC-M-4: API Client Missing Certificate Pinning

**Severity**: Medium (CWE-295: Improper Certificate Validation)  
**Location**: `lib/services/api_client.dart:29-35` (Dio initialization)

**The issue**: The API client does not implement certificate pinning. An attacker with network access (cafe WiFi, compromised ISP) could perform a MITM attack even with valid HTTPS, if they can present a CA-signed cert for `supabase.co`.

Dio + `dio_smart_retry` package support pinning, but it's not wired.

**Remediation** (2-3 hr, optional for beta):
```dart
// lib/services/api_client.dart
import 'package:dio_certificate_pinning/dio_certificate_pinning.dart';

ApiClient({...}) : ... {
  dio = Dio(BaseOptions(...));
  
  // Add certificate pinning for Supabase
  dio.interceptors.add(
    DioSmartRetry(
      // Built-in retry logic
    ),
  );
  
  // Manual pinning (if dio_certificate_pinning unavailable):
  // Load Supabase's cert from assets
  // Validate against it in a custom interceptor
}
```

**Timeline**: Pre-public-launch (nice-to-have for closed-beta).

---

#### SEC-M-5: Input Validation on User-Supplied Text Fields

**Severity**: Medium (CWE-20: Improper Input Validation)  
**Location**: Lost dog report form (`lib/screens/report_lost_screen.dart` inferred), dog name/breed/notes inputs

**The issue**: No visible validation on lost dog report fields. If a user submits a 10 MB note or a note with SQL injection payloads, the app may crash or send malformed data.

**Remediation** (1-2 hr):
```dart
// lib/screens/report_lost_screen.dart
class _ReportLostFormState extends State<ReportLostForm> {
  static const _maxNotesLength = 500;
  static const _maxNameLength = 100;

  final _notesController = TextEditingController();
  final _dogNameController = TextEditingController();

  String? _validateNotes(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value.length > _maxNotesLength) {
      return 'Notes must be under $_maxNotesLength characters';
    }
    // Optional: reject HTML/SQL-like patterns
    if (value.contains(RegExp(r'[<>\"\'`]'))) {
      return 'Notes contain invalid characters';
    }
    return null;
  }

  // Apply to TextFormField:
  TextFormField(
    controller: _notesController,
    validator: _validateNotes,
    maxLength: _maxNotesLength,
  )
}
```

**Timeline**: Pre-public-launch (low priority for closed-beta).

---

### Low

#### SEC-L-1: Offline Mode Toggle Can Be Persistent Across Device Lock

**Severity**: Low (CWE-287: Improper Authentication)  
**Location**: `lib/router.dart:85-100` (offline mode flag in plain Hive)

**The issue**: The `offline_mode` boolean is stored in an unencrypted Hive box (`dogquest_player_stats`). On a rooted/unlocked device, a malicious app can read / set this flag without authorization.

In practice, the attack surface is low because sightings are encrypted; setting offline mode only allows that attacker to log sightings (which are discarded on next auth). Not a primary vector.

**Remediation** (low priority, 1-2 hr):
Move the flag to FlutterSecureStorage:
```dart
// lib/router.dart
const storage = FlutterSecureStorage();
final offlineMode = (await storage.read(key: 'offline_mode')) == 'true';
```

**Timeline**: Post-beta (cosmetic).

---

#### SEC-L-2: No Dependency Vulnerability Scanning in CI/CD

**Severity**: Low (CWE-426: Untrusted Search Path)  
**Location**: Build configuration (Makefile, GitHub Actions)

**The issue**: The project does not run `dart pub audit` or use Snyk in CI/CD. New vulnerabilities in dependencies (e.g., a future CVE in flutter_map) would not be detected automatically.

**Remediation** (30 min setup):
```yaml
# .github/workflows/security.yml
name: Security
on: [push, pull_request]
jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
      - run: dart pub get
      - run: dart pub audit
```

**Timeline**: Post-launch (optional for closed-beta).

---

## GDPR-Specific Summary

### Pre-Public-Launch Checklist

| Item | Status | Effort | Blocker |
|------|--------|--------|---------|
| Privacy policy published | ✗ | 2-3 hr | **YES** |
| Consent dialog wired (Lost Dog) | ✗ | 1-2 hr | **YES** |
| DPA with Supabase signed | ✗ | 1 week (paperwork) | **YES** |
| Data retention policy (90-day expiry) | ✗ | 1 hr | YES |
| Contact info RPC stripped / "Request" flow | ✗ | 2-5 hr | **YES** |
| Photo cleanup on markFound | ✗ | 1-2 hr | YES |
| Location fuzzing (sightings) | ✗ | 1-2 hr | NO (nice-to-have) |
| Audit RLS policies | ✗ | 0.5 hr | **YES** |
| PII redaction in logs | ✗ | 1 hr | NO (pre-Sentry) |

**Total effort before public launch**: 12-20 hours (depends on privacy policy legal review).

**Closed-beta with friends-only acceptable if**: 
- You send explicit consent email: "Your contact info and GPS will be visible to other app users."
- You limit to 5-10 trusted people (not Play Store listing).
- You commit to full remediation before public launch.

---

## What's Secure

Auth state management is **clean** — C1 fix correctly invalidates stale offline flags on session creation. Supabase integration follows best practices: auth gate checks `currentSession` before allowing app access; Riverpod refresh listens to auth state changes; JWT is stored in FlutterSecureStorage (Keychain/Keystore backed); sightings box is AES-256 encrypted with a key in secure storage. Photo upload strips EXIF/GPS via image re-encoding. Hive box prefix isolation (`dogquest_`) prevents collision with AviQuest. Dependencies are modern (tflite_flutter 0.11, riverpod 2.5, go_router 14) and free of known vulnerabilities as of 2026-04-26. Android manifest disables backups, enforces HTTPS, and exports only the login activity. No hardcoded database URLs or API keys beyond Supabase's intentional public anonymous key.

---

## Open Questions for Jesse

1. **Network security config**: Can you verify `android/app/src/main/res/xml/network_security_config.xml` exists and disallows cleartext traffic + validates Supabase's CA chain?

2. **RLS policy audit**: Do you have access to the Supabase dashboard to verify RLS policies on `lost_dog_reports`, `lost_dog_sightings`, `friendships`, `packs` tables? Phase 1 trusted they exist; Phase 2A needs confirmation they're correct (e.g., `sightings_own (auth.uid() = user_id)`).

3. **Lost Dog feature timeline**: Are you shipping Lost Dog in closed-beta, or deferring it until GDPR remediation (SEC-C-Lost-1/2)? If closed-beta, will you send explicit consent email to beta testers?

4. **Privacy policy**: Does `https://dogquest.app/` exist yet? Do you have a privacy policy already drafted, or should this be part of the Phase 2A work?

5. **Supabase DPA**: Have you already signed a Data Processing Agreement with Supabase, or is this new?

---

## Remediation Priority

| Phase | Findings | Effort | Gate |
|-------|----------|--------|------|
| **Immediate** (pre-closed-beta) | SEC-C-Lost-1, SEC-C-Lost-2 (partial: privacy policy + consent) | 5-8 hr | Play Store / Legal |
| **Pre-public-launch** | SEC-C-Lost-2 (complete: DPA), SEC-H-Lost-1, SEC-H-1, SEC-H-2, SEC-H-4, SEC-M-2/3 | 12-20 hr | Play Store / GDPR |
| **Nice-to-have** | SEC-H-3, SEC-M-4, SEC-L-1/2 | 4-6 hr | Polish |

**Total pre-public-launch**: 20-28 hours (excluding legal review time).

---

## Confidence Assessment

**Solid (verified via code audit)**:
- C1 auth gate fix is correct
- C2 remains dormant (StateError blocks wiring)
- C3 backend removed
- Hive encryption sound
- Photo EXIF/GPS stripping implemented
- Android manifest hardening present

**Uncertain (requires out-of-scope verification)**:
- RLS policies on Supabase tables (need dashboard access)
- Network security config file contents
- Supabase DPA status

**Drifted (known absence, not regression)**:
- Privacy policy not present (expected pre-launch)
- Consent dialogs not wired (expected pre-launch)
- Lost Dog contact RPC broadcasts PII (architectural decision, not code bug)

---

## Next Steps

1. **Assign SEC-C-Lost-1 / SEC-C-Lost-2 to remediation** — these block public launch.
2. **Verify RLS policies** — share Supabase dashboard snapshots or run test queries.
3. **Confirm network security config** — share `android/.../network_security_config.xml`.
4. **Decide Lost Dog ship timeline** — closed-beta or defer?
5. **Re-run audit post-remediation** to confirm closures.

---

**Prepared for**: Closed-beta gate / pre-public-launch review  
**Audit completed**: 2026-04-26  
**Confidence**: Solid on code; uncertain on Supabase server-side policies
