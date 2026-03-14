/// A user's personal dog profile — their family dog registered in the app.
class MyDogProfile {
  final String name;
  final String? photoPath; // local file path
  final String? breed; // auto-detected or user-entered
  final String? breedConfidence; // 'auto' or 'manual'
  final DateTime? birthday;
  final DateTime? gotchaDay; // adoption date
  final bool usesGotchaDay; // true = rescue dog, show gotcha day instead of birthday
  final List<String> personalityTags;
  final DateTime createdAt;

  const MyDogProfile({
    required this.name,
    this.photoPath,
    this.breed,
    this.breedConfidence,
    this.birthday,
    this.gotchaDay,
    this.usesGotchaDay = false,
    this.personalityTags = const [],
    required this.createdAt,
  });

  /// The display date — birthday or gotcha day depending on user's choice.
  DateTime? get celebrationDate => usesGotchaDay ? gotchaDay : birthday;

  /// Age in years (approximate).
  int? get ageYears {
    final date = birthday ?? gotchaDay;
    if (date == null) return null;
    final now = DateTime.now();
    var age = now.year - date.year;
    if (now.month < date.month || (now.month == date.month && now.day < date.day)) {
      age--;
    }
    return age.clamp(0, 30);
  }

  /// Days until next celebration (birthday or gotcha day).
  int? get daysUntilCelebration {
    final date = celebrationDate;
    if (date == null) return null;
    final now = DateTime.now();
    var next = DateTime(now.year, date.month, date.day);
    if (next.isBefore(now) || next.isAtSameMomentAs(now)) {
      next = DateTime(now.year + 1, date.month, date.day);
    }
    return next.difference(now).inDays;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'photoPath': photoPath,
    'breed': breed,
    'breedConfidence': breedConfidence,
    'birthday': birthday?.toIso8601String(),
    'gotchaDay': gotchaDay?.toIso8601String(),
    'usesGotchaDay': usesGotchaDay,
    'personalityTags': personalityTags,
    'createdAt': createdAt.toIso8601String(),
  };

  factory MyDogProfile.fromJson(Map<String, dynamic> json) => MyDogProfile(
    name: json['name'] as String? ?? '',
    photoPath: json['photoPath'] as String?,
    breed: json['breed'] as String?,
    breedConfidence: json['breedConfidence'] as String?,
    birthday: json['birthday'] != null ? DateTime.tryParse(json['birthday'] as String) : null,
    gotchaDay: json['gotchaDay'] != null ? DateTime.tryParse(json['gotchaDay'] as String) : null,
    usesGotchaDay: json['usesGotchaDay'] as bool? ?? false,
    personalityTags: (json['personalityTags'] as List<dynamic>?)?.cast<String>() ?? [],
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );

  MyDogProfile copyWith({
    String? name,
    String? photoPath,
    String? breed,
    String? breedConfidence,
    DateTime? birthday,
    DateTime? gotchaDay,
    bool? usesGotchaDay,
    List<String>? personalityTags,
  }) => MyDogProfile(
    name: name ?? this.name,
    photoPath: photoPath ?? this.photoPath,
    breed: breed ?? this.breed,
    breedConfidence: breedConfidence ?? this.breedConfidence,
    birthday: birthday ?? this.birthday,
    gotchaDay: gotchaDay ?? this.gotchaDay,
    usesGotchaDay: usesGotchaDay ?? this.usesGotchaDay,
    personalityTags: personalityTags ?? this.personalityTags,
    createdAt: createdAt,
  );
}

/// Available personality tags for dog profiles.
const personalityOptions = [
  'Zoomies Monster',
  'Couch Potato',
  'Velcro Dog',
  'Food Obsessed',
  'Anxious Pup',
  'Water Dog',
  'Ball Fanatic',
  'Senior Sweetheart',
  'Puppy Chaos',
  'Guard Dog',
  'Gentle Giant',
  'Lap Dog',
  'Adventure Buddy',
  'Trick Master',
  'Chewer',
];
