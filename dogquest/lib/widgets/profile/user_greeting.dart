import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../constants.dart';
import '../../services/kennel_service.dart';
import '../../services/player_service.dart';
import 'avatar_picker_sheet.dart';

class UserGreeting extends ConsumerWidget {
  const UserGreeting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerBox = Hive.box('dogquest_player_stats');
    final username =
        playerBox.get('cached_username', defaultValue: null) as String?;
    final displayName =
        (username != null && username.isNotEmpty) ? username : 'Doger';
    final playerState = ref.watch(playerProvider);
    final customPhotoPath = Hive.box('dogquest_player_stats')
        .get('custom_avatar_path', defaultValue: '') as String;
    final isCustomPhoto = playerState.selectedAvatar == 'custom' &&
        customPhotoPath.isNotEmpty &&
        File(customPhotoPath).existsSync();
    final avatar = avatarOptions.firstWhere(
      (a) => a.id == playerState.selectedAvatar,
      orElse: () => avatarOptions.first,
    );

    return Row(
      children: [
        GestureDetector(
          onTap: () => _showAvatarPicker(context, ref),
          child: Stack(
            children: [
              isCustomPhoto
                  ? CircleAvatar(
                      radius: 22,
                      backgroundImage: FileImage(File(customPhotoPath)),
                    )
                  : CircleAvatar(
                      radius: 22,
                      backgroundColor: avatar.bgColor.withValues(alpha: 0.25),
                      child: Text(avatar.emoji,
                          style: const TextStyle(fontSize: 24)),
                    ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: bgDeep,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child:
                      const Icon(Icons.edit, size: 10, color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Hello, $displayName!',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _showAvatarPicker(BuildContext context, WidgetRef ref) {
    final playerState = ref.read(playerProvider);
    final kennelSvc = ref.read(kennelServiceProvider);
    final kennelCount = kennelSvc.all.length;
    final customPath = Hive.box('dogquest_player_stats')
        .get('custom_avatar_path', defaultValue: '') as String;

    showModalBottomSheet(
      context: context,
      backgroundColor: bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => AvatarPickerSheet(
          scrollController: scrollController,
          playerState: playerState,
          kennelCount: kennelCount,
          customPhotoPath: customPath,
          onSelect: (id) {
            ref.read(playerProvider.notifier).setAvatar(id);
            Navigator.pop(ctx);
          },
          onPickPhoto: () async {
            final picked = await ImagePicker().pickImage(
              source: ImageSource.gallery,
              maxWidth: 512,
              maxHeight: 512,
              imageQuality: 85,
            );
            if (picked == null) return;
            final appDir = await getApplicationDocumentsDirectory();
            final savedPath = '${appDir.path}/custom_avatar.jpg';
            await File(picked.path).copy(savedPath);
            Hive.box('dogquest_player_stats')
                .put('custom_avatar_path', savedPath);
            ref.read(playerProvider.notifier).setAvatar('custom');
            if (ctx.mounted) Navigator.pop(ctx);
          },
        ),
      ),
    );
  }
}
