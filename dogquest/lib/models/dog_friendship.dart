/// Friendship level between two dogs.
enum FriendshipLevel {
  newNeighbor(0, 'New Neighbor', '\u{1F44B}'),
  acquaintance(3, 'Acquaintance', '\u{1F43E}'),
  friend(7, 'Friend', '\u{1F496}'),
  bestFriend(14, 'Best Friend', '\u{1F31F}');

  final int visitsRequired;
  final String label;
  final String emoji;

  const FriendshipLevel(this.visitsRequired, this.label, this.emoji);

  /// XP bonus percentage for this friendship level.
  double get xpBonus {
    switch (this) {
      case FriendshipLevel.newNeighbor: return 0;
      case FriendshipLevel.acquaintance: return 0.05;
      case FriendshipLevel.friend: return 0.10;
      case FriendshipLevel.bestFriend: return 0.20;
    }
  }
}

/// A friendship between the user's dog and a neighborhood dog.
class DogFriendship {
  final String myDogName;
  final String neighborDogName;
  final String neighborBreed;
  final String neighborEmoji;
  final int visits;
  final DateTime lastVisit;
  final DateTime createdAt;

  const DogFriendship({
    required this.myDogName,
    required this.neighborDogName,
    required this.neighborBreed,
    required this.neighborEmoji,
    this.visits = 0,
    required this.lastVisit,
    required this.createdAt,
  });

  FriendshipLevel get level {
    if (visits >= FriendshipLevel.bestFriend.visitsRequired) return FriendshipLevel.bestFriend;
    if (visits >= FriendshipLevel.friend.visitsRequired) return FriendshipLevel.friend;
    if (visits >= FriendshipLevel.acquaintance.visitsRequired) return FriendshipLevel.acquaintance;
    return FriendshipLevel.newNeighbor;
  }

  int get visitsToNextLevel {
    final next = FriendshipLevel.values.where((l) => l.visitsRequired > visits).toList();
    if (next.isEmpty) return 0;
    return next.first.visitsRequired - visits;
  }

  double get progressToNextLevel {
    final currentReq = level.visitsRequired;
    final next = FriendshipLevel.values.where((l) => l.visitsRequired > visits).toList();
    if (next.isEmpty) return 1.0;
    final nextReq = next.first.visitsRequired;
    return (visits - currentReq) / (nextReq - currentReq);
  }

  bool get canVisitToday {
    final now = DateTime.now();
    return lastVisit.year != now.year || lastVisit.month != now.month || lastVisit.day != now.day;
  }

  Map<String, dynamic> toJson() => {
    'myDogName': myDogName,
    'neighborDogName': neighborDogName,
    'neighborBreed': neighborBreed,
    'neighborEmoji': neighborEmoji,
    'visits': visits,
    'lastVisit': lastVisit.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory DogFriendship.fromJson(Map<String, dynamic> json) => DogFriendship(
    myDogName: json['myDogName'] as String? ?? '',
    neighborDogName: json['neighborDogName'] as String? ?? '',
    neighborBreed: json['neighborBreed'] as String? ?? '',
    neighborEmoji: json['neighborEmoji'] as String? ?? '\u{1F436}',
    visits: json['visits'] as int? ?? 0,
    lastVisit: DateTime.tryParse(json['lastVisit'] as String? ?? '') ?? DateTime.now(),
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );

  DogFriendship copyWith({int? visits, DateTime? lastVisit}) => DogFriendship(
    myDogName: myDogName,
    neighborDogName: neighborDogName,
    neighborBreed: neighborBreed,
    neighborEmoji: neighborEmoji,
    visits: visits ?? this.visits,
    lastVisit: lastVisit ?? this.lastVisit,
    createdAt: createdAt,
  );
}

/// A dog that lives in the user's "neighborhood" — generated from the breed database.
class NeighborhoodDog {
  final String name;
  final String breed;
  final String emoji;
  final int gridX; // 0-3 position in neighborhood grid
  final int gridY; // 0-3 position in neighborhood grid
  final String personality;

  const NeighborhoodDog({
    required this.name,
    required this.breed,
    required this.emoji,
    required this.gridX,
    required this.gridY,
    required this.personality,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'breed': breed,
    'emoji': emoji,
    'gridX': gridX,
    'gridY': gridY,
    'personality': personality,
  };

  factory NeighborhoodDog.fromJson(Map<String, dynamic> json) => NeighborhoodDog(
    name: json['name'] as String? ?? '',
    breed: json['breed'] as String? ?? '',
    emoji: json['emoji'] as String? ?? '\u{1F436}',
    gridX: json['gridX'] as int? ?? 0,
    gridY: json['gridY'] as int? ?? 0,
    personality: json['personality'] as String? ?? '',
  );
}

/// Dog name + emoji pairs for neighborhood generation.
const neighborhoodDogNames = [
  ('Buddy', '\u{1F436}'),
  ('Luna', '\u{1F43A}'),
  ('Max', '\u{1F415}'),
  ('Bella', '\u{1F429}'),
  ('Charlie', '\u{1F9AE}'),
  ('Daisy', '\u{1F43E}'),
  ('Cooper', '\u{1F436}'),
  ('Sadie', '\u{1F415}'),
  ('Rocky', '\u{1F43A}'),
  ('Molly', '\u{1F429}'),
  ('Bear', '\u{1F43B}'),
  ('Maggie', '\u{1F43E}'),
  ('Duke', '\u{1F436}'),
  ('Bailey', '\u{1F415}'),
  ('Tucker', '\u{1F9AE}'),
  ('Chloe', '\u{1F429}'),
  ('Jack', '\u{1F43A}'),
  ('Sophie', '\u{1F43E}'),
  ('Toby', '\u{1F436}'),
  ('Penny', '\u{1F415}'),
];

const neighborhoodPersonalities = [
  'loves belly rubs',
  'always has zoomies',
  'barks at squirrels',
  'naps in the sun',
  'loves fetch',
  'steals socks',
  'howls at sirens',
  'great with kids',
  'champion digger',
  'snore champion',
  'treat motivated',
  'afraid of baths',
];
