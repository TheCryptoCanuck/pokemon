import 'package:dogquest/constants.dart';

/// Breed-specific dog years calculation.
/// Small dogs age slower than large dogs.
/// Uses the refined logarithmic formula.
int dogYears(int humanAge, String sizeCategory) {
  if (humanAge <= 0) return 0;
  // First 2 years are rapid aging
  // After that, each year adds differently by size
  final ratePerYear = switch (sizeCategory) {
    'small' => 4.0,
    'medium' => 5.0,
    'large' => 6.0,
    'giant' => 7.0,
    _ => 5.0,
  };
  if (humanAge <= 2) return (humanAge * 12).round();
  return 24 + ((humanAge - 2) * ratePerYear).round();
}

class Dog {
  final String name;
  final String scientificName;
  final String imageUrl;
  final String audioUrl;
  final String lore;
  final String habitat;
  final String conservationStatus;
  final Rarity rarity;
  final int baseXp;

  // Health & breed data fields
  final String lifespan;
  final String sizeCategory; // small / medium / large / giant
  final String weight;
  final String exerciseNeeds; // low / moderate / high / very high
  final String groomingNeeds; // low / moderate / high
  final List<String> healthPredispositions;
  final List<String> temperamentTraits;
  final String dietNotes;

  const Dog({
    required this.name,
    required this.scientificName,
    required this.imageUrl,
    required this.audioUrl,
    required this.lore,
    required this.habitat,
    required this.conservationStatus,
    required this.rarity,
    required this.baseXp,
    this.lifespan = '',
    this.sizeCategory = 'medium',
    this.weight = '',
    this.exerciseNeeds = 'moderate',
    this.groomingNeeds = 'moderate',
    this.healthPredispositions = const [],
    this.temperamentTraits = const [],
    this.dietNotes = '',
  });

  /// Defensive factory that tolerates missing or malformed fields.
  factory Dog.fromJson(Map<String, dynamic> json) {
    Rarity rarity;
    try {
      rarity = Rarity.values.byName(json['rarity'] as String? ?? 'common');
    } catch (_) {
      rarity = Rarity.common;
    }

    return Dog(
      name: json['name'] as String? ?? 'Unknown Breed',
      scientificName: json['scientificName'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      audioUrl: json['audioUrl'] as String? ?? '',
      lore: json['lore'] as String? ?? 'No information available.',
      habitat: json['habitat'] as String? ?? 'Unknown',
      conservationStatus: json['conservationStatus'] as String? ?? 'Unknown',
      rarity: rarity,
      baseXp: (json['baseXp'] as num?)?.toInt() ?? 20,
      lifespan: json['lifespan'] as String? ?? '',
      sizeCategory: json['sizeCategory'] as String? ?? 'medium',
      weight: json['weight'] as String? ?? '',
      exerciseNeeds: json['exerciseNeeds'] as String? ?? 'moderate',
      groomingNeeds: json['groomingNeeds'] as String? ?? 'moderate',
      healthPredispositions:
          (json['healthPredispositions'] as List<dynamic>?)?.cast<String>() ??
              const [],
      temperamentTraits:
          (json['temperamentTraits'] as List<dynamic>?)?.cast<String>() ??
              const [],
      dietNotes: json['dietNotes'] as String? ?? '',
    );
  }

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
        'lifespan': lifespan,
        'sizeCategory': sizeCategory,
        'weight': weight,
        'exerciseNeeds': exerciseNeeds,
        'groomingNeeds': groomingNeeds,
        'healthPredispositions': healthPredispositions,
        'temperamentTraits': temperamentTraits,
        'dietNotes': dietNotes,
      };

  int get xp {
    switch (rarity) {
      case Rarity.uncommon:
        return (baseXp * 1.5).round();
      case Rarity.rare:
        return baseXp * 2;
      case Rarity.legendary:
        return baseXp * 5;
      default:
        return baseXp;
    }
  }
}
