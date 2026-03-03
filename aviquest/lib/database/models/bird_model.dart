/// Database-serializable bird model for SQLite storage.
///
/// Provides toMap/fromMap conversions for SQLite operations while
/// maintaining compatibility with the existing Bird class in main.dart.
library;

class BirdRecord {
  final int? id;
  final String name;
  final String scientificName;
  final String imageUrl;
  final String audioUrl;
  final String lore;
  final String habitat;
  final String conservationStatus;
  final String rarity;
  final int baseXp;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BirdRecord({
    this.id,
    required this.name,
    required this.scientificName,
    required this.imageUrl,
    required this.audioUrl,
    required this.lore,
    required this.habitat,
    required this.conservationStatus,
    required this.rarity,
    required this.baseXp,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convert to SQLite-compatible map.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'scientific_name': scientificName,
      'image_url': imageUrl,
      'audio_url': audioUrl,
      'lore': lore,
      'habitat': habitat,
      'conservation_status': conservationStatus,
      'rarity': rarity,
      'base_xp': baseXp,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create from SQLite row map.
  factory BirdRecord.fromMap(Map<String, dynamic> map) {
    return BirdRecord(
      id: map['id'] as int?,
      name: map['name'] as String,
      scientificName: map['scientific_name'] as String,
      imageUrl: map['image_url'] as String,
      audioUrl: map['audio_url'] as String,
      lore: map['lore'] as String,
      habitat: map['habitat'] as String,
      conservationStatus: map['conservation_status'] as String,
      rarity: map['rarity'] as String,
      baseXp: map['base_xp'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Computed XP based on rarity multiplier.
  int get xp {
    switch (rarity) {
      case 'uncommon':
        return (baseXp * 1.5).round();
      case 'rare':
        return baseXp * 2;
      case 'legendary':
        return baseXp * 5;
      default:
        return baseXp;
    }
  }

  BirdRecord copyWith({
    int? id,
    String? name,
    String? scientificName,
    String? imageUrl,
    String? audioUrl,
    String? lore,
    String? habitat,
    String? conservationStatus,
    String? rarity,
    int? baseXp,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BirdRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      scientificName: scientificName ?? this.scientificName,
      imageUrl: imageUrl ?? this.imageUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      lore: lore ?? this.lore,
      habitat: habitat ?? this.habitat,
      conservationStatus: conservationStatus ?? this.conservationStatus,
      rarity: rarity ?? this.rarity,
      baseXp: baseXp ?? this.baseXp,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
