import 'package:flutter/material.dart';
import '../constants.dart';
import '../services/data_consent_service.dart';

/// One-time dialog asking the user to opt-in to aggregated data sharing.
///
/// Shown after the user's first identification with GPS coordinates.
/// The user can choose "Yes, Contribute" (opt-in) or "Not Now" (dismiss).
/// Either choice marks the prompt as shown so it doesn't appear again.
class DataConsentDialog {
  static Future<void> showIfNeeded(BuildContext context) async {
    if (DataConsentService.promptShown) return;

    await DataConsentService.markPromptShown();

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.science_outlined, color: Color(0xFFD4874E), size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Contribute to Science?',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your sightings can help conservation! When enabled, '
              'anonymized observation data (species, location, date) '
              'is shared with researchers and conservation partners.',
              style:
                  TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
            ),
            SizedBox(height: 16),
            Text(
              'What is shared:',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            _BulletItem('Species name & confidence'),
            _BulletItem('GPS coordinates & date/time'),
            SizedBox(height: 12),
            Text(
              'Never shared:',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            _BulletItem('Your name, email, or username'),
            _BulletItem('Photos or audio recordings'),
            SizedBox(height: 12),
            Text(
              'You can change this anytime in Settings.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Not Now',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          FilledButton.icon(
            onPressed: () async {
              await DataConsentService.setConsent(true);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            icon: const Icon(Icons.favorite, size: 16),
            label: const Text('Yes, Contribute'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD4874E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  const _BulletItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 5, color: Colors.white38),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
