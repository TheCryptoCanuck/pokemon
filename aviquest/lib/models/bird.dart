import '../constants.dart';

class Bird {
  final String name;
  final String scientificName;
  final String imageUrl;
  final String audioUrl;
  final String lore;
  final String habitat;
  final String conservationStatus;
  final Rarity rarity;
  final int baseXp;

  const Bird({
    required this.name,
    required this.scientificName,
    required this.imageUrl,
    required this.audioUrl,
    required this.lore,
    required this.habitat,
    required this.conservationStatus,
    required this.rarity,
    required this.baseXp,
  });

  factory Bird.fromJson(Map<String, dynamic> json) => Bird(
    name: json['name'] as String,
    scientificName: json['scientificName'] as String,
    imageUrl: json['imageUrl'] as String,
    audioUrl: json['audioUrl'] as String,
    lore: json['lore'] as String,
    habitat: json['habitat'] as String,
    conservationStatus: json['conservationStatus'] as String,
    rarity: Rarity.values.byName(json['rarity'] as String),
    baseXp: json['baseXp'] as int,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'scientificName': scientificName,
    'imageUrl': imageUrl,
    'audioUrl': audioUrl,
    'lore': lore,
    'habitat': habitat,
    'conservationStatus': conservationStatus,
    'rarity': rarity.name,
    'baseXp': baseXp,
  };

  int get xp {
    switch (rarity) {
      case Rarity.uncommon: return (baseXp * 1.5).round();
      case Rarity.rare: return baseXp * 2;
      case Rarity.legendary: return baseXp * 5;
      default: return baseXp;
    }
  }
}
