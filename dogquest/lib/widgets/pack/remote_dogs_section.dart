import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../services/supabase_pack_service.dart';

class RemoteDogsSection extends StatelessWidget {
  final PackRemote pack;
  final List<PackDogRemote> dogs;
  final VoidCallback onAddDog;

  const RemoteDogsSection({
    required this.pack,
    required this.dogs,
    required this.onAddDog,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Pack Dogs',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber)),
            const Spacer(),
            GestureDetector(
              onTap: onAddDog,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.pets, color: Colors.amber, size: 14),
                  SizedBox(width: 4),
                  Text('Add Dog',
                      style: TextStyle(
                          color: Colors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (dogs.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgCard,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text('No dogs added yet. Tap "Add Dog" above!',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: dogs.map((dog) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (dog.photoUrl != null)
                      CircleAvatar(
                        radius: 14,
                        backgroundImage: NetworkImage(dog.photoUrl!),
                      )
                    else
                      const Icon(Icons.pets, color: Colors.amber, size: 16),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(dog.dogName,
                            style: const TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                        Text(dog.breed ?? '',
                            style: const TextStyle(
                                color: textSecondary, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
