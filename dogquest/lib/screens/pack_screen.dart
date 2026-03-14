import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../constants.dart';
import '../models/pack.dart';
import '../services/kennel_service.dart';
import '../services/my_dog_service.dart';
import '../services/pack_service.dart';
import '../services/player_service.dart';
import '../widgets/weekly_pack_report.dart';

class PackScreen extends ConsumerStatefulWidget {
  const PackScreen({super.key});

  @override
  ConsumerState<PackScreen> createState() => _PackScreenState();
}

class _PackScreenState extends ConsumerState<PackScreen> {
  @override
  Widget build(BuildContext context) {
    final packSvc = ref.read(packServiceProvider);
    final pack = packSvc.pack;

    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AppBar(
        backgroundColor: bgDeep,
        title: Text(pack?.name ?? 'My Pack',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (pack != null)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white54, size: 20),
              onPressed: () => _editPackName(pack),
              tooltip: 'Edit pack',
            ),
        ],
      ),
      body: pack == null ? _buildCreatePack() : _buildPackView(pack),
    );
  }

  // ─── Create Pack ───────────────────────────────────────────────────

  Widget _buildCreatePack() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('\u{1F43E}', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 20),
            const Text('Start Your Pack',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            const Text(
              'Create a family pack to share your dogs, track combined stats, and see weekly reports together.',
              style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showCreatePackDialog,
              icon: const Icon(Icons.group_add),
              label: const Text('Create Pack'),
            ),
          ],
        ).animate().fadeIn().slideY(begin: 0.1),
      ),
    );
  }

  void _showCreatePackDialog() {
    final nameCtrl = TextEditingController();
    String selectedEmoji = packEmojiOptions[0];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Name Your Pack', style: TextStyle(color: Colors.amber)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji picker
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: packEmojiOptions.map((emoji) => GestureDetector(
                  onTap: () => setDialogState(() => selectedEmoji = emoji),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: selectedEmoji == emoji
                          ? Colors.amber.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selectedEmoji == emoji ? Colors.amber : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g., The Smiths',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                _createPack(name, selectedEmoji);
                Navigator.pop(ctx);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _createPack(String name, String emoji) {
    final packSvc = ref.read(packServiceProvider);
    final myDogSvc = ref.read(myDogServiceProvider);

    // Auto-add creator as alpha with their registered dogs
    final myDogs = myDogSvc.dogs;
    final alpha = PackMember(
      name: 'Me',
      role: 'alpha',
      avatarEmoji: memberAvatarOptions[0],
      dogNames: myDogs.map((d) => d.name).toList(),
      joinedAt: DateTime.now(),
    );

    final pack = Pack(
      name: name,
      emoji: emoji,
      inviteCode: Pack.generateInviteCode(),
      members: [alpha],
      createdAt: DateTime.now(),
    );

    packSvc.createPack(pack);
    ref.read(playerProvider.notifier).awardBonusXp(25);
    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: bgCard,
          content: Text('Pack created! +25 XP', style: TextStyle(color: Colors.amber)),
        ),
      );
    }
  }

  // ─── Pack View ─────────────────────────────────────────────────────

  Widget _buildPackView(Pack pack) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pack header with invite code
          _buildPackHeader(pack),
          const SizedBox(height: 20),

          // Weekly Pack Report
          WeeklyPackReport(pack: pack),
          const SizedBox(height: 20),

          // Members section
          _buildMembersSection(pack),
          const SizedBox(height: 20),

          // Pack stats
          _buildPackStats(pack),
          const SizedBox(height: 32),

          // Danger zone
          Center(
            child: TextButton(
              onPressed: () => _confirmDeletePack(),
              child: const Text('Disband Pack', style: TextStyle(color: Colors.red, fontSize: 12)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPackHeader(Pack pack) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.amber.withValues(alpha: 0.12),
          Colors.orange.withValues(alpha: 0.06),
        ]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(pack.emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          Text(pack.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text('${pack.members.length} member${pack.members.length == 1 ? '' : 's'} \u2022 ${pack.totalDogs} dog${pack.totalDogs == 1 ? '' : 's'}',
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 16),

          // Invite code
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.vpn_key, color: Colors.amber, size: 16),
                const SizedBox(width: 10),
                Text(pack.inviteCode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: 3,
                      fontFamily: 'monospace',
                    )),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: pack.inviteCode));
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: bgCard,
                        duration: Duration(seconds: 2),
                        content: Text('Invite code copied!', style: TextStyle(color: Colors.amber)),
                      ),
                    );
                  },
                  child: const Icon(Icons.copy, color: Colors.white54, size: 18),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Share.share(
                      'Join my pack "${pack.name}" on DogQuest! Use invite code: ${pack.inviteCode}',
                    );
                  },
                  child: const Icon(Icons.share, color: Colors.white54, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildMembersSection(Pack pack) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Pack Members',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber)),
            const Spacer(),
            if (pack.members.length < 8)
              GestureDetector(
                onTap: () => _showAddMemberDialog(pack),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.person_add, color: Colors.amber, size: 14),
                    SizedBox(width: 4),
                    Text('Add', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...pack.members.asMap().entries.map((entry) {
          final member = entry.value;
          return _buildMemberCard(pack, member);
        }),
      ],
    );
  }

  Widget _buildMemberCard(Pack pack, PackMember member) {
    final myDogSvc = ref.read(myDogServiceProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: member.isAlpha ? Colors.amber.withValues(alpha: 0.3) : Colors.white12,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: member.isAlpha
                      ? Colors.amber.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(member.avatarEmoji ?? '\u{1F9D1}', style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(member.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    if (member.isAlpha) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Alpha', style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ]),
                  Text('${member.dogNames.length} dog${member.dogNames.length == 1 ? '' : 's'}',
                      style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ]),
              ),
              if (!member.isAlpha)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white24, size: 18),
                  onPressed: () => _confirmRemoveMember(member),
                  tooltip: 'Remove',
                ),
            ],
          ),
          // Dog names
          if (member.dogNames.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: member.dogNames.map((name) {
                final dogProfile = myDogSvc.getDog(name);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.pets, size: 12, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(name, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    if (dogProfile?.breed != null) ...[
                      const Text(' \u2022 ', style: TextStyle(color: Colors.white24, fontSize: 11)),
                      Text(dogProfile!.breed!, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ]),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildPackStats(Pack pack) {
    final kennelSvc = ref.read(kennelServiceProvider);
    final playerState = ref.watch(playerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pack Stats',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber)),
        const SizedBox(height: 12),
        Row(
          children: [
            _packStatCard('\u{1F43E}', '${pack.totalDogs}', 'Pack Dogs', Colors.amber),
            const SizedBox(width: 10),
            _packStatCard('\u{1F4DA}', '${kennelSvc.count}', 'Breeds Found', const Color(0xFFD4874E)),
            const SizedBox(width: 10),
            _packStatCard('\u{26A1}', '${playerState.level}', 'Pack Level', const Color(0xFF7C4DFF)),
          ],
        ).animate().fadeIn(delay: 100.ms),
      ],
    );
  }

  Widget _packStatCard(String emoji, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  // ─── Dialogs ───────────────────────────────────────────────────────

  void _showAddMemberDialog(Pack pack) {
    final nameCtrl = TextEditingController();
    String selectedEmoji = memberAvatarOptions[0];
    final myDogSvc = ref.read(myDogServiceProvider);
    final allDogs = myDogSvc.dogs;
    final assignedDogNames = pack.members.expand((m) => m.dogNames).toSet();
    final availableDogs = allDogs.where((d) => !assignedDogNames.contains(d.name)).toList();
    final selectedDogs = <String>{};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Pack Member', style: TextStyle(color: Colors.amber)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar picker
                Wrap(
                  spacing: 6,
                  children: memberAvatarOptions.map((emoji) => GestureDetector(
                    onTap: () => setDialogState(() => selectedEmoji = emoji),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: selectedEmoji == emoji
                            ? Colors.amber.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selectedEmoji == emoji ? Colors.amber : Colors.transparent,
                        ),
                      ),
                      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Name',
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                if (availableDogs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Assign dogs:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 6),
                  ...availableDogs.map((dog) => CheckboxListTile(
                    title: Text(dog.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    subtitle: dog.breed != null
                        ? Text(dog.breed!, style: const TextStyle(color: Colors.white38, fontSize: 11))
                        : null,
                    value: selectedDogs.contains(dog.name),
                    onChanged: (v) => setDialogState(() {
                      if (v == true) {
                        selectedDogs.add(dog.name);
                      } else {
                        selectedDogs.remove(dog.name);
                      }
                    }),
                    activeColor: Colors.amber,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  )),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final packSvc = ref.read(packServiceProvider);
                packSvc.addMember(PackMember(
                  name: name,
                  avatarEmoji: selectedEmoji,
                  dogNames: selectedDogs.toList(),
                  joinedAt: DateTime.now(),
                ));
                Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveMember(PackMember member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Member?', style: TextStyle(color: Colors.white)),
        content: Text('Remove ${member.name} from the pack?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              ref.read(packServiceProvider).removeMember(member.name);
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _editPackName(Pack pack) {
    final nameCtrl = TextEditingController(text: pack.name);
    String selectedEmoji = pack.emoji;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Pack', style: TextStyle(color: Colors.amber)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: packEmojiOptions.map((emoji) => GestureDetector(
                  onTap: () => setDialogState(() => selectedEmoji = emoji),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: selectedEmoji == emoji
                          ? Colors.amber.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selectedEmoji == emoji ? Colors.amber : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Pack name',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                ref.read(packServiceProvider).updatePack(
                  pack.copyWith(name: name, emoji: selectedEmoji),
                );
                Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePack() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Disband Pack?', style: TextStyle(color: Colors.red)),
        content: const Text(
          'This will permanently delete your pack and all member data. This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Pack', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              ref.read(packServiceProvider).deletePack();
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Disband', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
