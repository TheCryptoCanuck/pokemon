import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../constants.dart';
import '../models/my_dog_profile.dart';
import '../services/dog_service.dart';
import '../services/identification_service.dart';
import '../services/my_dog_service.dart';
import '../services/player_service.dart';

class MyDogWizardScreen extends ConsumerStatefulWidget {
  const MyDogWizardScreen({super.key});

  @override
  ConsumerState<MyDogWizardScreen> createState() => _MyDogWizardScreenState();
}

class _MyDogWizardScreenState extends ConsumerState<MyDogWizardScreen> {
  final _pageController = PageController();
  int _currentStep = 0;

  // Step 1: Name
  final _nameController = TextEditingController();

  // Step 2: Photo + auto-detect breed
  String? _photoPath;
  String? _detectedBreed;
  bool _detectingBreed = false;

  // Step 3: Birthday / Gotcha Day
  DateTime? _birthday;
  DateTime? _gotchaDay;
  bool _usesGotchaDay = false;

  // Step 4: Personality
  final Set<String> _selectedTraits = {};
  bool _traitsPreSelected = false; // true once breed suggestions applied

  @override
  void dispose() {
    _nameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 4) {
      setState(() => _currentStep++);
      _pageController.animateToPage(_currentStep, duration: 300.ms, curve: Curves.easeOutCubic);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(_currentStep, duration: 300.ms, curve: Curves.easeOutCubic);
    }
  }

  bool get _canProceed {
    switch (_currentStep) {
      case 0: return _nameController.text.trim().isNotEmpty;
      case 1: return true; // photo is optional
      case 2: return true; // date is optional
      case 3: return true; // traits optional
      default: return true;
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    // Save to app directory
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = 'my_dog_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedPath = '${appDir.path}/$fileName';
    await File(picked.path).copy(savedPath);

    setState(() {
      _photoPath = savedPath;
      _detectedBreed = null;
    });

    // Auto-detect breed from photo
    _autoDetectBreed(File(savedPath));
  }

  Future<void> _autoDetectBreed(File imageFile) async {
    setState(() => _detectingBreed = true);
    try {
      final idService = ref.read(identificationServiceProvider);
      final results = await idService.identify(imageFile).timeout(const Duration(seconds: 10));
      if (results.isNotEmpty && mounted) {
        setState(() {
          _detectedBreed = results.first.dog.name;
          _preselectTraitsForBreed(_detectedBreed!);
        });
      }
    } catch (_) {
      // Silently fail — breed detection is a delight, not a requirement
    } finally {
      if (mounted) setState(() => _detectingBreed = false);
    }
  }

  /// Maps breed temperament traits to personality options and pre-selects them.
  void _preselectTraitsForBreed(String breedName) {
    final dogSvc = ref.read(dogServiceProvider);
    final breed = dogSvc.lookupByCommonName(breedName);
    if (breed == null || breed.temperamentTraits.isEmpty) return;

    // Mapping from temperament trait keywords (lowercase) to personality options
    const temperamentToPersonality = <String, String>{
      'friendly': 'Velcro Dog',
      'affectionate': 'Velcro Dog',
      'loving': 'Velcro Dog',
      'clingy': 'Velcro Dog',
      'active': 'Zoomies Monster',
      'energetic': 'Zoomies Monster',
      'playful': 'Zoomies Monster',
      'spirited': 'Zoomies Monster',
      'calm': 'Couch Potato',
      'gentle': 'Couch Potato',
      'relaxed': 'Couch Potato',
      'easygoing': 'Couch Potato',
      'loyal': 'Guard Dog',
      'protective': 'Guard Dog',
      'watchful': 'Guard Dog',
      'alert': 'Guard Dog',
      'brave': 'Guard Dog',
      'independent': 'Adventure Buddy',
      'adventurous': 'Adventure Buddy',
      'curious': 'Adventure Buddy',
      'bold': 'Adventure Buddy',
      'intelligent': 'Trick Master',
      'smart': 'Trick Master',
      'trainable': 'Trick Master',
      'clever': 'Trick Master',
      'obedient': 'Trick Master',
      'eager to please': 'Trick Master',
      'water-loving': 'Water Dog',
      'swimmer': 'Water Dog',
      'patient': 'Gentle Giant',
      'tolerant': 'Gentle Giant',
      'good-natured': 'Gentle Giant',
      'stubborn': 'Chewer',
      'mischievous': 'Puppy Chaos',
      'timid': 'Anxious Pup',
      'shy': 'Anxious Pup',
      'nervous': 'Anxious Pup',
      'sensitive': 'Anxious Pup',
      'devoted': 'Lap Dog',
      'cuddly': 'Lap Dog',
    };

    final matched = <String>{};
    for (final trait in breed.temperamentTraits) {
      final lower = trait.toLowerCase();
      // Check exact match first, then check if any key is contained in the trait
      if (temperamentToPersonality.containsKey(lower)) {
        matched.add(temperamentToPersonality[lower]!);
      } else {
        for (final entry in temperamentToPersonality.entries) {
          if (lower.contains(entry.key) || entry.key.contains(lower)) {
            matched.add(entry.value);
            break;
          }
        }
      }
    }

    if (matched.isNotEmpty) {
      _selectedTraits.addAll(matched);
      _traitsPreSelected = true;
    }
  }

  Future<void> _saveDog() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final profile = MyDogProfile(
      name: name,
      photoPath: _photoPath,
      breed: _detectedBreed,
      breedConfidence: _detectedBreed != null ? 'auto' : null,
      birthday: _usesGotchaDay ? null : _birthday,
      gotchaDay: _usesGotchaDay ? _gotchaDay : null,
      usesGotchaDay: _usesGotchaDay,
      personalityTags: _selectedTraits.toList(),
      createdAt: DateTime.now(),
    );

    ref.read(myDogServiceProvider).addDog(profile);

    // Award XP for registering a dog
    ref.read(playerProvider.notifier).awardBonusXp(50);

    if (mounted) {
      // Show celebration, then pop
      setState(() => _currentStep = 4);
      _pageController.animateToPage(4, duration: 400.ms, curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentStep > 0 && _currentStep < 4
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                onPressed: _prevStep,
              )
            : IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
        title: _currentStep < 4
            ? Text('Step ${_currentStep + 1} of 4', style: const TextStyle(color: Colors.white54, fontSize: 14))
            : null,
      ),
      body: Column(
        children: [
          // Progress bar
          if (_currentStep < 4)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / 4,
                  minHeight: 4,
                  backgroundColor: bgCard,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildNameStep(),
                _buildPhotoStep(),
                _buildDateStep(),
                _buildPersonalityStep(),
                _buildCelebrationStep(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 1: Name ───────────────────────────────────────────────
  Widget _buildNameStep() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.pets, color: Colors.amber, size: 48)
              .animate().fadeIn().scale(begin: const Offset(0.5, 0.5), curve: Curves.elasticOut),
          const SizedBox(height: 24),
          const Text(
            "What's their name?",
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 32),
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'e.g. Biscuit',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 24),
              filled: true,
              fillColor: bgCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) { if (_canProceed) _nextStep(); },
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 32),
          _buildNextButton(),
        ],
      ),
    );
  }

  // ─── Step 2: Photo ──────────────────────────────────────────────
  Widget _buildPhotoStep() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Show us ${_nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'your dog'}!',
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ).animate().fadeIn(),
          const SizedBox(height: 8),
          const Text(
            'Snap a photo or pick from gallery',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 32),

          // Photo preview or placeholder
          GestureDetector(
            onTap: () => _showPhotoSourceSheet(),
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 2),
                image: _photoPath != null
                    ? DecorationImage(image: FileImage(File(_photoPath!)), fit: BoxFit.cover)
                    : null,
              ),
              child: _photoPath == null
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_a_photo, color: Colors.amber.withValues(alpha: 0.5), size: 48),
                      const SizedBox(height: 8),
                      const Text('Tap to add photo', style: TextStyle(color: Colors.white38, fontSize: 13)),
                    ])
                  : null,
            ),
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 16),

          // Breed detection result
          if (_detectingBreed)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber)),
              const SizedBox(width: 8),
              const Text('Detecting breed...', style: TextStyle(color: Colors.amber, fontSize: 13)),
            ]).animate().fadeIn()
          else if (_detectedBreed != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Text('Looks like a $_detectedBreed!',
                    style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),

          const SizedBox(height: 32),

          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton(
              onPressed: _nextStep,
              child: Text(
                _photoPath == null ? 'Skip for now' : 'Next',
                style: TextStyle(color: _photoPath == null ? Colors.white54 : Colors.amber, fontSize: 16),
              ),
            ),
            if (_photoPath != null) ...[
              const SizedBox(width: 16),
              _buildNextButton(),
            ],
          ]),
        ],
      ),
    );
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: const Icon(Icons.camera_alt, color: Colors.amber),
            title: const Text('Take a photo', style: TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(ctx); _pickPhoto(ImageSource.camera); },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: Colors.amber),
            title: const Text('Choose from gallery', style: TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(ctx); _pickPhoto(ImageSource.gallery); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ─── Step 3: Birthday / Gotcha Day ──────────────────────────────
  Widget _buildDateStep() {
    final dogName = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'your dog';

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "When was $dogName born?",
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ).animate().fadeIn(),
          const SizedBox(height: 24),

          // Toggle: Birthday vs Gotcha Day
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _dateTypeChip('Birthday', !_usesGotchaDay, () => setState(() => _usesGotchaDay = false)),
            const SizedBox(width: 12),
            _dateTypeChip('Gotcha Day', _usesGotchaDay, () => setState(() => _usesGotchaDay = true)),
          ]),

          if (_usesGotchaDay)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: const Text("The day you adopted them",
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),

          const SizedBox(height: 24),

          // Date picker button
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: (_usesGotchaDay ? _gotchaDay : _birthday) ?? DateTime.now().subtract(const Duration(days: 365)),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
                builder: (ctx, child) => Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: const ColorScheme.dark(primary: Colors.amber, surface: Color(0xFF2A1F1A)),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                setState(() {
                  if (_usesGotchaDay) {
                    _gotchaDay = picked;
                  } else {
                    _birthday = picked;
                  }
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.calendar_today, color: Colors.amber.withValues(alpha: 0.7), size: 20),
                const SizedBox(width: 12),
                Text(
                  _getDateText(),
                  style: TextStyle(
                    color: _hasDate ? Colors.white : Colors.white38,
                    fontSize: 18,
                    fontWeight: _hasDate ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ]),
            ),
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 32),

          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton(
              onPressed: _nextStep,
              child: Text(
                _hasDate ? 'Next' : 'Skip for now',
                style: TextStyle(color: _hasDate ? Colors.amber : Colors.white54, fontSize: 16),
              ),
            ),
            if (_hasDate) ...[
              const SizedBox(width: 16),
              _buildNextButton(),
            ],
          ]),
        ],
      ),
    );
  }

  bool get _hasDate => _usesGotchaDay ? _gotchaDay != null : _birthday != null;

  String _getDateText() {
    final date = _usesGotchaDay ? _gotchaDay : _birthday;
    if (date == null) return 'Pick a date';
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _dateTypeChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.amber.withValues(alpha: 0.15) : bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.amber : Colors.white12),
        ),
        child: Text(label,
          style: TextStyle(
            color: selected ? Colors.amber : Colors.white54,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ─── Step 4: Personality ────────────────────────────────────────
  Widget _buildPersonalityStep() {
    final dogName = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'your dog';

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Text(
            "What's $dogName like?",
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ).animate().fadeIn(),
          const SizedBox(height: 8),
          const Text('Pick as many as you like',
              style: TextStyle(color: Colors.white54, fontSize: 14)),
          if (_traitsPreSelected && _detectedBreed != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Suggested for $_detectedBreed',
                style: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ).animate().fadeIn(),
          ],
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8, runSpacing: 10,
                children: personalityOptions.asMap().entries.map((e) {
                  final trait = e.value;
                  final selected = _selectedTraits.contains(trait);
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (selected) {
                          _selectedTraits.remove(trait);
                        } else {
                          _selectedTraits.add(trait);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: 200.ms,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? Colors.amber.withValues(alpha: 0.15) : bgCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? Colors.amber : Colors.white12,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(trait,
                        style: TextStyle(
                          color: selected ? Colors.amber : Colors.white70,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: Duration(milliseconds: (e.key * 30).clamp(0, 300)));
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveDog,
              child: const Text('Done!'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 5: Celebration ────────────────────────────────────────
  Widget _buildCelebrationStep() {
    final dogName = _nameController.text.trim();

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Welcome to DogQuest!',
            style: TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.w600),
          ).animate().fadeIn(),
          const SizedBox(height: 16),

          // Dog card preview
          Container(
            width: 260,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: bgCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 2),
              boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.15), blurRadius: 30)],
            ),
            child: Column(children: [
              if (_photoPath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(File(_photoPath!), width: 160, height: 160, fit: BoxFit.cover),
                )
              else
                Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.pets, color: Colors.amber, size: 56),
                ),
              const SizedBox(height: 16),
              Text(dogName,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              if (_detectedBreed != null) ...[
                const SizedBox(height: 4),
                Text(_detectedBreed!,
                  style: const TextStyle(color: Colors.amber, fontSize: 14)),
              ],
              if (_selectedTraits.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 4, runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: _selectedTraits.take(4).map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(t, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                  )).toList(),
                ),
              ],
              const SizedBox(height: 12),
              const Text('+50 XP', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
          ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.8, 0.8), curve: Curves.elasticOut),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Let\'s go!'),
            ),
          ).animate().fadeIn(delay: 600.ms),
        ],
      ),
    );
  }

  Widget _buildNextButton() {
    return ElevatedButton(
      onPressed: _canProceed ? _nextStep : null,
      child: const Icon(Icons.arrow_forward),
    );
  }
}
