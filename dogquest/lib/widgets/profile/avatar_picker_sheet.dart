import 'dart:io';

import 'package:flutter/material.dart';

import 'package:dogquest/constants.dart';
import 'package:dogquest/services/player_service.dart';

class AvatarPickerSheet extends StatelessWidget {
  final ScrollController scrollController;
  final PlayerState playerState;
  final int kennelCount;
  final String customPhotoPath;
  final void Function(String id) onSelect;
  final VoidCallback onPickPhoto;

  const AvatarPickerSheet({
    required this.scrollController,
    required this.playerState,
    required this.kennelCount,
    required this.customPhotoPath,
    required this.onSelect,
    required this.onPickPhoto,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // +1 for the custom photo tile at the end
    final totalItems = avatarOptions.length + 1;
    final hasCustomPhoto =
        customPhotoPath.isNotEmpty && File(customPhotoPath).existsSync();

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Choose Avatar',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Unlock more by collecting breeds and earning achievements',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.builder(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: totalItems,
            itemBuilder: (_, i) {
              // Last tile = custom photo
              if (i == avatarOptions.length) {
                final isSelected = playerState.selectedAvatar == 'custom';
                return GestureDetector(
                  onTap: onPickPhoto,
                  child: Container(
                    decoration: BoxDecoration(
                      color: hasCustomPhoto
                          ? Colors.teal
                              .withValues(alpha: isSelected ? 0.3 : 0.1)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? Colors.amber
                            : Colors.white.withValues(alpha: 0.1),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (hasCustomPhoto)
                          CircleAvatar(
                            radius: 18,
                            backgroundImage: FileImage(File(customPhotoPath)),
                          )
                        else
                          Icon(
                            Icons.add_a_photo_rounded,
                            color: Colors.white.withValues(alpha: 0.4),
                            size: 28,
                          ),
                        const SizedBox(height: 6),
                        Text(
                          hasCustomPhoto ? 'My Photo' : 'Upload Photo',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasCustomPhoto
                              ? 'Tap to change'
                              : 'Use your own photo',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.38),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final avatar = avatarOptions[i];
              final unlocked = avatar.isUnlocked(
                playerState.level,
                kennelCount,
                playerState.unlockedAchievements,
                playerState.streak,
                playerState.totalSightings,
              );
              final isSelected = playerState.selectedAvatar == avatar.id;

              return GestureDetector(
                onTap: unlocked ? () => onSelect(avatar.id) : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: unlocked
                        ? avatar.bgColor
                            .withValues(alpha: isSelected ? 0.3 : 0.1)
                        : Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? Colors.amber
                          : unlocked
                              ? avatar.bgColor.withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.05),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (unlocked)
                        Text(avatar.emoji, style: const TextStyle(fontSize: 32))
                      else
                        Icon(
                          Icons.lock_rounded,
                          color: Colors.white.withValues(alpha: 0.15),
                          size: 32,
                        ),
                      const SizedBox(height: 6),
                      Text(
                        avatar.name,
                        style: TextStyle(
                          color: unlocked ? Colors.white : Colors.white24,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          avatar.description,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: unlocked ? Colors.white38 : Colors.white12,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
