import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dogquest/constants.dart';
import 'package:dogquest/models/dog.dart';
import 'package:dogquest/services/dog_service.dart';
import 'package:dogquest/services/my_dog_service.dart';
import 'package:dogquest/screens/dog_passport_screen.dart';

class MyDogProfileScreen extends ConsumerWidget {
  final String dogName;

  const MyDogProfileScreen({super.key, required this.dogName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dog = ref.read(myDogServiceProvider).getDog(dogName);
    if (dog == null) {
      return Scaffold(
        backgroundColor: bgDeep,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(
          child: Text('Dog not found', style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    // Look up breed data from the breed database
    final Dog? breedData = dog.breed != null
        ? ref.read(dogServiceProvider).lookupByCommonName(dog.breed!)
        : null;

    return Scaffold(
      backgroundColor: bgDeep,
      body: CustomScrollView(
        slivers: [
          // Hero header with photo
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: bgDeep,
            flexibleSpace: FlexibleSpaceBar(
              background: dog.photoPath != null &&
                      File(dog.photoPath!).existsSync()
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(File(dog.photoPath!), fit: BoxFit.cover),
                        // Gradient overlay
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, bgDeep],
                              stops: [0.5, 1.0],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      color: bgCard,
                      child: const Center(
                        child: Icon(Icons.pets, color: Colors.amber, size: 80),
                      ),
                    ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Name
                  Text(
                    dog.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ).animate().fadeIn(),

                  // Breed
                  if (dog.breed != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        dog.breed!,
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ).animate().fadeIn(delay: 100.ms),
                  ],

                  const SizedBox(height: 20),

                  // Info cards row
                  Row(
                    children: [
                      if (dog.ageYears != null)
                        _InfoCard(
                          icon: Icons.cake,
                          value: '${dog.ageYears}',
                          label: dog.ageYears == 1 ? 'year old' : 'years old',
                          color: Colors.pink,
                        ),
                      if (dog.daysUntilCelebration != null) ...[
                        if (dog.ageYears != null) const SizedBox(width: 12),
                        _InfoCard(
                          icon: dog.usesGotchaDay
                              ? Icons.favorite
                              : Icons.celebration,
                          value: '${dog.daysUntilCelebration}',
                          label: dog.daysUntilCelebration == 1
                              ? 'day until ${dog.usesGotchaDay ? "gotcha day" : "birthday"}'
                              : 'days until ${dog.usesGotchaDay ? "gotcha day" : "birthday"}',
                          color: Colors.amber,
                        ),
                      ],
                      // Dog Years card — only if age and breed data available
                      if (dog.ageYears != null && breedData != null) ...[
                        const SizedBox(width: 12),
                        _InfoCard(
                          icon: Icons.timeline,
                          value:
                              '${dogYears(dog.ageYears!, breedData.sizeCategory)}',
                          label: 'dog years',
                          color: Colors.deepPurpleAccent,
                        ),
                      ],
                    ],
                  ).animate().fadeIn(delay: 150.ms),

                  // Personality tags
                  if (dog.personalityTags.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Personality',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: dog.personalityTags
                          .map(
                            (t) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                t,
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ).animate().fadeIn(delay: 200.ms),
                  ],

                  // ─── Breed Insights Section ─────────────────────────
                  if (breedData != null) ...[
                    const SizedBox(height: 28),
                    _BreedInsightsCard(breed: breedData),
                  ],

                  // Passport button
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DogPassportScreen(dogName: dog.name),
                        ),
                      ),
                      icon: const Icon(Icons.badge, size: 22),
                      label: const Text(
                        'View Passport',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4874E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        shadowColor:
                            const Color(0xFFD4874E).withValues(alpha: 0.4),
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

                  // Member since
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: bgCard,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.pets,
                          color: Colors.amber.withValues(alpha: 0.5),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Hound member since ${_formatDate(dog.createdAt)}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 250.ms),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Breed Insights Card ──────────────────────────────────────────────────────

class _BreedInsightsCard extends StatelessWidget {
  final Dog breed;

  const _BreedInsightsCard({required this.breed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.biotech,
                color: Colors.amber.withValues(alpha: 0.8),
                size: 22,
              ),
              const SizedBox(width: 10),
              const Text(
                'Breed Insights',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ).animate().fadeIn(),

          const SizedBox(height: 16),

          // Mini info cards row: lifespan, size, weight
          Row(
            children: [
              if (breed.lifespan.isNotEmpty)
                _MiniInfoTile(
                  icon: Icons.favorite_border,
                  label: 'Lifespan',
                  value: breed.lifespan,
                ),
              if (breed.lifespan.isNotEmpty) const SizedBox(width: 10),
              _MiniInfoTile(
                icon: Icons.straighten,
                label: 'Size',
                value: _sizeLabel(breed.sizeCategory),
              ),
              if (breed.weight.isNotEmpty) ...[
                const SizedBox(width: 10),
                _MiniInfoTile(
                  icon: Icons.monitor_weight_outlined,
                  label: 'Weight',
                  value: breed.weight,
                ),
              ],
            ],
          ).animate().fadeIn(delay: 50.ms),

          const SizedBox(height: 16),

          // Exercise & grooming needs
          Row(
            children: [
              Expanded(
                child: _NeedsIndicator(
                  label: 'Exercise',
                  level: breed.exerciseNeeds,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NeedsIndicator(
                  label: 'Grooming',
                  level: breed.groomingNeeds,
                  color: Colors.blue,
                ),
              ),
            ],
          ).animate().fadeIn(delay: 100.ms),

          // Health predispositions
          if (breed.healthPredispositions.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'Health Watch',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...breed.healthPredispositions.map(
              (h) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.amber.withValues(alpha: 0.7),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        h,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Temperament traits as chips
          if (breed.temperamentTraits.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'Temperament',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: breed.temperamentTraits
                  .map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.deepPurple.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        t,
                        style: const TextStyle(
                          color: Colors.deepPurpleAccent,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],

          // Diet notes
          if (breed.dietNotes.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Icon(
                  Icons.restaurant,
                  color: Colors.amber.withValues(alpha: 0.6),
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Diet Notes',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              breed.dietNotes,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 250.ms)
        .slideY(begin: 0.05, curve: Curves.easeOut);
  }

  static String _sizeLabel(String s) => switch (s) {
        'small' => 'Small',
        'medium' => 'Medium',
        'large' => 'Large',
        'giant' => 'Giant',
        _ => 'Medium',
      };
}

class _MiniInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: bgDeep,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.amber.withValues(alpha: 0.6), size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NeedsIndicator extends StatelessWidget {
  final String label;
  final String level;
  final Color color;

  const _NeedsIndicator({
    required this.label,
    required this.level,
    required this.color,
  });

  int get _filledDots => switch (level) {
        'low' => 1,
        'moderate' => 2,
        'high' => 3,
        'very high' => 4,
        _ => 2,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            ...List.generate(
              4,
              (i) => Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _filledDots
                      ? color.withValues(alpha: 0.8)
                      : Colors.white12,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              level,
              style:
                  TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}
