import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dogquest/constants.dart';
import 'package:dogquest/models/my_dog_profile.dart';
import 'package:dogquest/services/my_dog_service.dart';
import 'package:dogquest/services/lost_dog_service.dart';

class ReportLostScreen extends ConsumerStatefulWidget {
  const ReportLostScreen({super.key});

  @override
  ConsumerState<ReportLostScreen> createState() => _ReportLostScreenState();
}

class _ReportLostScreenState extends ConsumerState<ReportLostScreen> {
  MyDogProfile? _selectedDog;
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _contactController = TextEditingController();
  bool _isSubmitting = false;
  bool _submitted = false;
  final List<File> _additionalPhotos = [];
  bool _gdprConsent = false;

  @override
  void dispose() {
    _notesController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedDog == null) return;
    if (!_formKey.currentState!.validate()) return;
    if (!_gdprConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the privacy terms to continue.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final lostDogService = ref.read(lostDogServiceProvider);
      await lostDogService.reportLost(
        _selectedDog!,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        ownerContact: _contactController.text.trim().isEmpty
            ? null
            : _contactController.text.trim(),
        additionalPhotos: _additionalPhotos,
        gdprConsentAt: _gdprConsent ? DateTime.now() : null,
      );
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitted = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  Future<void> _pickAdditionalPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() {
      _additionalPhotos.add(File(picked.path));
    });
  }

  @override
  Widget build(BuildContext context) {
    final dogs = ref.watch(myDogServiceProvider).dogs;

    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Report a Lost Dog',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: _submitted
          ? _buildSuccessView()
          : dogs.isEmpty
              ? _buildNoDogs()
              : _buildForm(dogs),
    );
  }

  // ─── No Dogs Registered ─────────────────────────────────────────────────

  Widget _buildNoDogs() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: bgCard,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pets, color: Colors.amber, size: 40),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Dogs Registered',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Create a dog profile first so we can generate a visual embedding for matching.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.white54, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/my-dog-wizard'),
                icon: const Icon(Icons.add, size: 22),
                label: const Text(
                  'Create Dog Profile',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Success View ───────────────────────────────────────────────────────

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.green.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: const Icon(Icons.check, color: Colors.green, size: 50),
            ),
            const SizedBox(height: 28),
            const Text(
              'Report Filed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${_selectedDog?.name ?? "Your dog"} has been added to the Lost Dog Recognition Network.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Every DogQuest user who scans a stray will automatically check against this report. We hope to bring them home soon.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Main Form ──────────────────────────────────────────────────────────

  Widget _buildForm(List<MyDogProfile> dogs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section: Select your dog
            const Text(
              'Which dog is missing?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Select the dog you want to report as lost.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Dog selection cards
            ...dogs.map(
              (dog) => _DogSelectionCard(
                dog: dog,
                isSelected: _selectedDog?.name == dog.name,
                onTap: () => setState(() => _selectedDog = dog),
              ),
            ),

            // Selected dog detail + form fields
            if (_selectedDog != null) ...[
              const SizedBox(height: 28),

              // Notes field
              const Text(
                'Additional Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Collar color, distinguishing marks, last seen location, etc.',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: _inputDecoration(
                  hint:
                      'e.g. Red collar, scar on left ear, last seen near Central Park',
                  icon: Icons.note_alt_outlined,
                ),
              ),

              const SizedBox(height: 20),

              // Contact field
              const Text(
                'Contact Info',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'How should someone reach you if they find your dog?',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactController,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: _inputDecoration(
                  hint: 'Phone number or email',
                  icon: Icons.phone_outlined,
                ),
              ),

              const SizedBox(height: 32),

              // Embedding info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: Colors.amber.withValues(alpha: 0.7),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'A visual fingerprint will be generated from your dog\'s photo to match against stray scans.',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Additional photos section
              _AdditionalPhotosSection(
                photos: _additionalPhotos,
                onAdd: _pickAdditionalPhoto,
                onRemove: (i) => setState(() => _additionalPhotos.removeAt(i)),
              ),

              const SizedBox(height: 24),

              // GDPR consent checkbox
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _gdprConsent,
                    onChanged: (newValue) {
                      setState(() => _gdprConsent = newValue ?? false);
                    },
                    activeColor: const Color(0xFFD84315),
                    fillColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return const Color(0xFFD84315);
                      }
                      return Colors.white24;
                    }),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            const TextSpan(
                              text:
                                  'I agree my contact details may be shared with verified users who report a sighting. ',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 14,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  launchUrl(
                                    Uri.parse('https://dogquest.app/privacy'),
                                    mode: LaunchMode.externalApplication,
                                  );
                                },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitReport,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.warning_amber_rounded, size: 24),
                  label: Text(
                    _isSubmitting
                        ? 'Generating visual fingerprint${_additionalPhotos.isEmpty ? '' : ' (${_additionalPhotos.length + 1} photos)'}...'
                        : 'Report as Lost',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD84315),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        const Color(0xFFD84315).withValues(alpha: 0.5),
                    disabledForegroundColor: Colors.white60,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: const Color(0xFFD84315).withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.white38, size: 20),
      filled: true,
      fillColor: bgCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Colors.amber.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

// ─── Dog Selection Card ────────────────────────────────────────────────────────

class _DogSelectionCard extends StatelessWidget {
  final MyDogProfile dog;
  final bool isSelected;
  final VoidCallback onTap;

  const _DogSelectionCard({
    required this.dog,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFD84315).withValues(alpha: 0.12)
                  : bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFD84315).withValues(alpha: 0.6)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // Dog photo
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: dog.photoPath != null &&
                            File(dog.photoPath!).existsSync()
                        ? Image.file(
                            File(dog.photoPath!),
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: bgDeep,
                            child: const Icon(
                              Icons.pets,
                              color: Colors.amber,
                              size: 28,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),

                // Dog info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dog.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (dog.breed != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          dog.breed!,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Selection indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? const Color(0xFFD84315)
                        : Colors.transparent,
                    border: Border.all(
                      color:
                          isSelected ? const Color(0xFFD84315) : Colors.white24,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdditionalPhotosSection extends StatelessWidget {
  final List<File> photos;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _AdditionalPhotosSection({
    required this.photos,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'More Photos',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${photos.length}/2 — optional)',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'More photos = better fingerprint. Add up to 2 extra shots.',
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Existing additional photo thumbnails
            for (int i = 0; i < photos.length; i++) ...[
              _PhotoThumb(file: photos[i], onRemove: () => onRemove(i)),
              const SizedBox(width: 8),
            ],

            // Add button (only if < 2 additional photos)
            if (photos.length < 2) _AddPhotoButton(onTap: onAdd),
          ],
        ),
      ],
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;

  const _PhotoThumb({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            file,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddPhotoButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddPhotoButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white24,
            style: BorderStyle.solid,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              color: Colors.white38,
              size: 24,
            ),
            SizedBox(height: 4),
            Text(
              'Add',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
