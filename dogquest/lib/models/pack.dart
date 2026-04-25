import 'dart:math';

/// A member of a Pack (family group).
class PackMember {
  final String name;
  final String role; // 'alpha' or 'member'
  final String? avatarEmoji;
  final List<String> dogNames; // linked MyDogProfile names
  final DateTime joinedAt;

  const PackMember({
    required this.name,
    this.role = 'member',
    this.avatarEmoji,
    this.dogNames = const [],
    required this.joinedAt,
  });

  bool get isAlpha => role == 'alpha';

  Map<String, dynamic> toJson() => {
        'name': name,
        'role': role,
        'avatarEmoji': avatarEmoji,
        'dogNames': dogNames,
        'joinedAt': joinedAt.toIso8601String(),
      };

  factory PackMember.fromJson(Map<String, dynamic> json) => PackMember(
        name: json['name'] as String? ?? '',
        role: json['role'] as String? ?? 'member',
        avatarEmoji: json['avatarEmoji'] as String?,
        dogNames: (json['dogNames'] as List<dynamic>?)?.cast<String>() ?? [],
        joinedAt: DateTime.tryParse(json['joinedAt'] as String? ?? '') ??
            DateTime.now(),
      );

  PackMember copyWith({
    String? name,
    String? role,
    String? avatarEmoji,
    List<String>? dogNames,
  }) =>
      PackMember(
        name: name ?? this.name,
        role: role ?? this.role,
        avatarEmoji: avatarEmoji ?? this.avatarEmoji,
        dogNames: dogNames ?? this.dogNames,
        joinedAt: joinedAt,
      );
}

/// A Pack represents a family group that shares dogs and stats.
class Pack {
  final String name;
  final String emoji;
  final String inviteCode;
  final List<PackMember> members;
  final DateTime createdAt;

  /// Weekly activity tracking
  final int weeklyBreedsFound;
  final int weeklyXpEarned;
  final int weeklyActiveDays;
  final String? weeklyStartDate; // ISO date key for current tracking week

  const Pack({
    required this.name,
    this.emoji = '\u{1F43E}',
    required this.inviteCode,
    this.members = const [],
    required this.createdAt,
    this.weeklyBreedsFound = 0,
    this.weeklyXpEarned = 0,
    this.weeklyActiveDays = 0,
    this.weeklyStartDate,
  });

  int get totalDogs => members.fold(0, (sum, m) => sum + m.dogNames.length);

  PackMember? get alpha {
    try {
      return members.firstWhere((m) => m.isAlpha);
    } catch (_) {
      return members.isNotEmpty ? members.first : null;
    }
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'emoji': emoji,
        'inviteCode': inviteCode,
        'members': members.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'weeklyBreedsFound': weeklyBreedsFound,
        'weeklyXpEarned': weeklyXpEarned,
        'weeklyActiveDays': weeklyActiveDays,
        'weeklyStartDate': weeklyStartDate,
      };

  factory Pack.fromJson(Map<String, dynamic> json) => Pack(
        name: json['name'] as String? ?? '',
        emoji: json['emoji'] as String? ?? '\u{1F43E}',
        inviteCode: json['inviteCode'] as String? ?? '',
        members: (json['members'] as List<dynamic>?)
                ?.map((m) => PackMember.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        weeklyBreedsFound: json['weeklyBreedsFound'] as int? ?? 0,
        weeklyXpEarned: json['weeklyXpEarned'] as int? ?? 0,
        weeklyActiveDays: json['weeklyActiveDays'] as int? ?? 0,
        weeklyStartDate: json['weeklyStartDate'] as String?,
      );

  Pack copyWith({
    String? name,
    String? emoji,
    List<PackMember>? members,
    int? weeklyBreedsFound,
    int? weeklyXpEarned,
    int? weeklyActiveDays,
    String? weeklyStartDate,
  }) =>
      Pack(
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        inviteCode: inviteCode,
        members: members ?? this.members,
        createdAt: createdAt,
        weeklyBreedsFound: weeklyBreedsFound ?? this.weeklyBreedsFound,
        weeklyXpEarned: weeklyXpEarned ?? this.weeklyXpEarned,
        weeklyActiveDays: weeklyActiveDays ?? this.weeklyActiveDays,
        weeklyStartDate: weeklyStartDate ?? this.weeklyStartDate,
      );

  /// Generate a random 6-character invite code.
  static String generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}

/// Emoji options for pack identity.
const packEmojiOptions = [
  '\u{1F43E}', // paw
  '\u{1F3E0}', // house
  '\u{1F436}', // dog face
  '\u{1F43A}', // wolf
  '\u{2B50}', // star
  '\u{1F525}', // fire
  '\u{1F496}', // sparkling heart
  '\u{1F308}', // rainbow
  '\u{1F3C6}', // trophy
  '\u{1F6E1}', // shield
  '\u{26A1}', // lightning
  '\u{1F31F}', // glowing star
];

/// Emoji options for member avatars.
const memberAvatarOptions = [
  '\u{1F468}', // man
  '\u{1F469}', // woman
  '\u{1F466}', // boy
  '\u{1F467}', // girl
  '\u{1F9D1}', // person
  '\u{1F474}', // old man
  '\u{1F475}', // old woman
  '\u{1F476}', // baby
];
