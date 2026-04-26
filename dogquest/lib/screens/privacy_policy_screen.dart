import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dogquest/constants.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AppBar(
        backgroundColor: bgDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title:
            const Text('Privacy Policy', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DogQuest Privacy Policy',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Last updated: March 2026',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 20),
            _body(
              'Thank you for using DogQuest. This privacy policy explains how '
              'we collect, use, and protect your information when you use our '
              'dog identification app.',
            ),
            const SizedBox(height: 24),
            _heading('1. Information We Collect'),
            const SizedBox(height: 8),
            _body(
              'When you create an account, we collect the following information:',
            ),
            const SizedBox(height: 8),
            _bullet('Username'),
            _bullet('Email address'),
            _bullet('Password (stored securely using one-way hashing)'),
            _bullet(
              'Dog collection data (species identified, sighting history)',
            ),
            _bullet(
                'Location data (GPS coordinates) when you identify a species, '
                'if you have granted location permission'),
            _bullet(
              'Basic device information (OS version, app version) for troubleshooting',
            ),
            const SizedBox(height: 24),
            _heading('2. Camera Usage'),
            const SizedBox(height: 8),
            _body(
              'DogQuest requests camera access solely for the purpose of dog '
              'identification. Photos taken through the app are processed '
              'entirely on your device. Images are NOT uploaded to any server '
              'or shared with any third party. After identification is '
              'complete, the photo data remains on your device only.',
            ),
            const SizedBox(height: 24),
            _heading('3. On-Device Machine Learning'),
            const SizedBox(height: 8),
            _body(
              'Dog identification is powered by a TensorFlow Lite model that '
              'runs entirely on your device. No images, audio, or sensor data '
              'are sent to external services for identification purposes. All '
              'inference happens locally, ensuring your photos never leave '
              'your phone.',
            ),
            const SizedBox(height: 24),
            _heading('3a. Location Data'),
            const SizedBox(height: 8),
            _body(
              'When you grant location permission, DogQuest records the GPS '
              'coordinates (latitude, longitude, and accuracy) of each species '
              'identification. This data is stored locally on your device and '
              'is used to:',
            ),
            const SizedBox(height: 8),
            _bullet('Filter identification results by geographic plausibility'),
            _bullet('Show your sightings on a map'),
            _bullet('Enable location-based achievements and challenges'),
            const SizedBox(height: 24),
            _heading('4. Data Storage'),
            const SizedBox(height: 8),
            _body(
              'App data such as your dog collection, sighting history, XP '
              'progress, and achievements are stored locally on your device '
              'using an on-device database (Hive). If you create an account, '
              'your collection data is synced to our backend server so you '
              'can restore your progress if you switch devices.',
            ),
            const SizedBox(height: 24),
            _heading('5. Third-Party Services'),
            const SizedBox(height: 8),
            _body(
              'DogQuest uses the following third-party services to enhance '
              'your experience:',
            ),
            const SizedBox(height: 8),
            _bullet(
              'Dog breed reference images are loaded from various image '
              'sources. Your IP address may be visible to image hosting '
              'servers when images are fetched.',
            ),
            _bullet(
              'Dog breed audio samples are provided for educational purposes. '
              'Your IP address may be visible to third-party servers when audio '
              'is played.',
            ),
            const SizedBox(height: 8),
            _body(
              'We do not use any advertising SDKs, analytics trackers, or '
              'social media integrations.',
            ),
            const SizedBox(height: 24),
            _heading('6. Data Sharing'),
            const SizedBox(height: 8),
            _body(
              'We do not sell your personal data (name, email, password) to '
              'third parties.',
            ),
            const SizedBox(height: 12),
            _heading('6a. Aggregated Sighting Data (Opt-In)'),
            const SizedBox(height: 8),
            _body(
              'If you opt in to "Contribute to Science" in Settings, your '
              'species observation data may be shared in aggregated, '
              'de-identified form with:',
            ),
            const SizedBox(height: 8),
            _bullet(
              'Conservation organizations and researchers studying wildlife '
              'populations and biodiversity',
            ),
            _bullet(
              'Environmental consulting firms conducting ecological impact '
              'assessments',
            ),
            _bullet(
              'Government agencies managing wildlife and natural resources',
            ),
            const SizedBox(height: 8),
            _body(
              'Shared data includes: species name, date/time, GPS coordinates, '
              'and identification confidence. It does NOT include your name, '
              'email, username, photos, or audio recordings. You can opt out '
              'at any time in Settings, and future sightings will no longer be '
              'included.',
            ),
            const SizedBox(height: 24),
            _heading('7. Data Deletion'),
            const SizedBox(height: 8),
            _body(
              'You can delete your local app data at any time by clearing the '
              'app storage or uninstalling the app. To request deletion of '
              'your account and all associated server-side data, please '
              'contact us at the email address below. We will process your '
              'request within 30 days.',
            ),
            const SizedBox(height: 24),
            _heading('8. Children\'s Privacy'),
            const SizedBox(height: 8),
            _body(
              'DogQuest does not knowingly collect personal information from '
              'children under the age of 13. If you believe a child has '
              'provided us with personal data, please contact us so we can '
              'remove it promptly.',
            ),
            const SizedBox(height: 24),
            _heading('9. Changes to This Policy'),
            const SizedBox(height: 8),
            _body(
              'We may update this privacy policy from time to time. Any '
              'changes will be reflected in the "Last updated" date at the '
              'top of this page. Continued use of the app after changes '
              'constitutes acceptance of the updated policy.',
            ),
            const SizedBox(height: 24),
            _heading('10. Contact Us'),
            const SizedBox(height: 8),
            _body(
              'If you have any questions, concerns, or requests regarding '
              'this privacy policy or your personal data, please contact us:',
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'support@dogquest.app',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  static Widget _heading(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.amber,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  static Widget _body(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 14,
        height: 1.5,
      ),
    );
  }

  static Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: Icon(Icons.circle, size: 6, color: Colors.white38),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
