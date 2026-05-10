import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dogquest/constants.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

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
        title: const Text(
          'Terms of Service',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hound Terms of Service',
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

            // ── 1. Acceptance of Terms ──
            _heading('1. Acceptance of Terms'),
            const SizedBox(height: 8),
            _body(
              'By downloading, installing, or using the Hound application '
              '("the App"), you agree to be bound by these Terms of Service '
              '("Terms"). If you do not agree to these Terms, do not use the '
              'App. We reserve the right to update these Terms at any time. '
              'Continued use of the App after changes are posted constitutes '
              'your acceptance of the revised Terms.',
            ),
            const SizedBox(height: 24),

            // ── 2. Description of Service ──
            _heading('2. Description of Service'),
            const SizedBox(height: 8),
            _body(
              'Hound is a mobile application that uses on-device machine '
              'learning to identify dog breeds from photos. The App also '
              'provides gamification features, social features, lost dog '
              'reporting, breed information, and community interactions. '
              'The App is provided on an "as is" and "as available" basis.',
            ),
            const SizedBox(height: 24),

            // ── 3. User Accounts ──
            _heading('3. User Accounts'),
            const SizedBox(height: 8),
            _body(
              'To access certain features, you must create an account. '
              'You are responsible for:',
            ),
            const SizedBox(height: 8),
            _bullet(
              'Maintaining the confidentiality of your login credentials',
            ),
            _bullet('All activity that occurs under your account'),
            _bullet(
              'Providing accurate and current information during registration',
            ),
            const SizedBox(height: 8),
            _body(
              'You must be at least 13 years old to create an account. '
              'If you are under 18, you must have the consent of a parent '
              'or legal guardian.',
            ),
            const SizedBox(height: 24),

            // ── 4. User-Generated Content ──
            _heading('4. User-Generated Content'),
            const SizedBox(height: 8),
            _body(
              'You may submit content through the App, including but not '
              'limited to social posts, dog photos, lost dog reports, '
              'breed community comments, and playdate requests '
              '("User Content").',
            ),
            const SizedBox(height: 12),
            _subheading('Ownership'),
            const SizedBox(height: 4),
            _body(
              'You retain full ownership of all User Content you submit. '
              'By submitting User Content, you grant Hound a non-exclusive, '
              'worldwide, royalty-free, sublicensable license to use, display, '
              'reproduce, and distribute your User Content solely for the '
              'purpose of operating, promoting, and improving the App. This '
              'license ends when you delete your User Content or your account.',
            ),
            const SizedBox(height: 12),
            _subheading('Responsibility'),
            const SizedBox(height: 4),
            _body(
              'You are solely responsible for the User Content you submit. '
              'You represent and warrant that you have all rights necessary '
              'to grant the licenses described above and that your User '
              'Content does not violate any applicable law or the rights '
              'of any third party.',
            ),
            const SizedBox(height: 24),

            // ── 5. Prohibited Content & Conduct ──
            _heading('5. Prohibited Content & Conduct'),
            const SizedBox(height: 8),
            _body(
              'You agree not to use the App to:',
            ),
            const SizedBox(height: 8),
            _bullet('Harass, bully, threaten, or intimidate other users'),
            _bullet('Post spam, unsolicited promotions, or repetitive content'),
            _bullet(
                'Submit false or misleading lost dog reports, which may cause '
                'unnecessary alarm and waste community resources'),
            _bullet('Post content that is defamatory, obscene, violent, or '
                'otherwise objectionable'),
            _bullet('Impersonate another person or entity'),
            _bullet('Attempt to reverse-engineer, decompile, or extract the '
                'machine learning models or source code'),
            _bullet('Use automated means (bots, scrapers) to access the App'),
            _bullet(
              'Upload content that infringes intellectual property rights',
            ),
            const SizedBox(height: 24),

            // ── 6. Account Termination ──
            _heading('6. Account Termination'),
            const SizedBox(height: 8),
            _body(
              'We reserve the right to suspend or terminate your account at '
              'our sole discretion, with or without notice, if we reasonably '
              'believe that you have violated these Terms. Grounds for '
              'termination include but are not limited to:',
            ),
            const SizedBox(height: 8),
            _bullet('Repeated violations of the prohibited conduct policy'),
            _bullet('Submitting false lost dog reports'),
            _bullet('Harassment of other users'),
            _bullet('Attempting to compromise app security or integrity'),
            const SizedBox(height: 8),
            _body(
              'Upon termination, your right to use the App ceases immediately. '
              'You may request export of your data prior to termination by '
              'contacting us.',
            ),
            const SizedBox(height: 24),

            // ── 7. Breed Identification Disclaimer ──
            _heading('7. Breed Identification Disclaimer'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF3A2A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.amber,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Important Notice',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _body(
                    'Dog breed identification provided by Hound is for '
                    'entertainment and informational purposes only. It is NOT '
                    'a substitute for professional veterinary advice, diagnosis, '
                    'or treatment. Breed identification results may be inaccurate '
                    'and should not be relied upon for medical, behavioral, '
                    'insurance, legal, or breeding decisions. Always consult a '
                    'qualified veterinarian or professional dog breeder for '
                    'authoritative breed identification.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── 8. Lost Dog Reports ──
            _heading('8. Lost Dog Reports'),
            const SizedBox(height: 8),
            _body(
              'The lost dog reporting feature is provided as a community service '
              'tool. Hound does not guarantee the accuracy, completeness, or '
              'effectiveness of lost dog reports. We are not responsible for '
              'the outcome of any lost dog situation. Submitting knowingly false '
              'lost dog reports is a violation of these Terms and may result in '
              'immediate account termination.',
            ),
            const SizedBox(height: 24),

            // ── 9. Intellectual Property ──
            _heading('9. Intellectual Property'),
            const SizedBox(height: 8),
            _body(
              'The App, including its design, code, machine learning models, '
              'graphics, icons, and branding, is the property of Hound and '
              'is protected by applicable intellectual property laws. You may '
              'not copy, modify, distribute, or create derivative works based '
              'on the App without our prior written consent.',
            ),
            const SizedBox(height: 24),

            // ── 10. Limitation of Liability ──
            _heading('10. Limitation of Liability'),
            const SizedBox(height: 8),
            _body(
              'To the maximum extent permitted by applicable law, Hound and '
              'its developers, officers, and affiliates shall not be liable for '
              'any indirect, incidental, special, consequential, or punitive '
              'damages, including but not limited to:',
            ),
            const SizedBox(height: 8),
            _bullet('Loss of data or content'),
            _bullet(
              'Damages arising from reliance on breed identification results',
            ),
            _bullet('Damages arising from interactions with other users'),
            _bullet('Damages arising from lost dog report outcomes'),
            _bullet('Service interruptions, bugs, or errors in the App'),
            const SizedBox(height: 8),
            _body(
              'In no event shall our total liability to you exceed the amount '
              'you have paid to Hound in the twelve (12) months preceding '
              'the claim, or fifty US dollars (\$50), whichever is greater.',
            ),
            const SizedBox(height: 24),

            // ── 11. Disclaimer of Warranties ──
            _heading('11. Disclaimer of Warranties'),
            const SizedBox(height: 8),
            _body(
              'The App is provided "as is" and "as available" without warranties '
              'of any kind, whether express or implied, including but not limited '
              'to implied warranties of merchantability, fitness for a particular '
              'purpose, and non-infringement. We do not warrant that the App '
              'will be uninterrupted, error-free, or that breed identification '
              'results will be accurate.',
            ),
            const SizedBox(height: 24),

            // ── 12. Governing Law ──
            _heading('12. Governing Law'),
            const SizedBox(height: 8),
            _body(
              'These Terms shall be governed by and construed in accordance '
              'with the laws of the State of Delaware, United States, without '
              'regard to its conflict of law provisions. Any disputes arising '
              'from these Terms or the App shall be resolved in the courts '
              'of the State of Delaware.',
            ),
            const SizedBox(height: 24),

            // ── 13. Contact Us ──
            _heading('13. Contact Us'),
            const SizedBox(height: 8),
            _body(
              'If you have any questions about these Terms, please contact us:',
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
                    'jesseg.8899@gmail.com',
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

  static Widget _subheading(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFD4874E),
        fontSize: 14,
        fontWeight: FontWeight.w600,
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
