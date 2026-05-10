import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dogquest/constants.dart';
import 'package:dogquest/services/my_dog_service.dart';

class MyDogCard extends ConsumerWidget {
  const MyDogCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myDogSvc = ref.read(myDogServiceProvider);
    final dogs = myDogSvc.dogs;

    if (dogs.isEmpty) {
      // No dogs yet — show "Add your dog" CTA
      return GestureDetector(
        onTap: () => context.push('/my-dog/wizard'),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 8, bottom: 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.amber.withValues(alpha: 0.12),
                Colors.orange.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.pets, color: Colors.amber, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Your Dog',
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Create a profile for your furry friend — earn 50 XP!',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.amber,
                size: 16,
              ),
            ],
          ),
        ),
      ).animate().fadeIn().slideY(begin: 0.05);
    }

    // Show registered dogs
    return Column(
      children: [
        ...dogs.map(
          (dog) => GestureDetector(
            onTap: () => context
                .push('/my-dog/profile/${Uri.encodeComponent(dog.name)}'),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  // Dog photo or placeholder
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: dog.photoPath != null &&
                            File(dog.photoPath!).existsSync()
                        ? Image.file(
                            File(dog.photoPath!),
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 52,
                            height: 52,
                            color: Colors.amber.withValues(alpha: 0.1),
                            child: const Icon(
                              Icons.pets,
                              color: Colors.amber,
                              size: 28,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dog.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (dog.breed != null)
                              Text(
                                dog.breed!,
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 12,
                                ),
                              ),
                            if (dog.breed != null && dog.ageYears != null)
                              const Text(
                                ' • ',
                                style: TextStyle(
                                  color: Colors.white24,
                                  fontSize: 12,
                                ),
                              ),
                            if (dog.ageYears != null)
                              Text(
                                '${dog.ageYears} yr${dog.ageYears == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        if (dog.daysUntilCelebration != null &&
                            dog.daysUntilCelebration! <= 30)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.pink.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${dog.usesGotchaDay ? "Gotcha day" : "Birthday"} in ${dog.daysUntilCelebration} days!',
                                style: const TextStyle(
                                  color: Colors.pink,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white24),
                ],
              ),
            ),
          ).animate().fadeIn(),
        ),

        // Add another dog button
        if (dogs.length < 5)
          GestureDetector(
            onTap: () => context.push('/my-dog/wizard'),
            child: Container(
              margin: const EdgeInsets.only(top: 4, bottom: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    color: Colors.white.withValues(alpha: 0.3),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Add another dog',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
