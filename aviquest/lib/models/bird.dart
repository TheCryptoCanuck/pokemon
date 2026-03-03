import 'package:flutter/material.dart';

const rarityColors = {
  'common': Colors.white70,
  'uncommon': Color(0xFF4CAF50),
  'rare': Color(0xFF2196F3),
  'legendary': Colors.amber,
  'unknown': Color(0xFFCE93D8),
};

class Bird {
  final String name;
  final String scientificName;
  final String imageUrl;
  final String audioUrl;
  final String lore;
  final String habitat;
  final String conservationStatus;
  final String rarity;
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

  factory Bird.fromJson(Map<String, dynamic> json) {
    return Bird(
      name: json['name'] as String,
      scientificName: json['scientificName'] as String,
      imageUrl: json['imageUrl'] as String,
      audioUrl: json['audioUrl'] as String,
      lore: json['lore'] as String,
      habitat: json['habitat'] as String,
      conservationStatus: json['conservationStatus'] as String,
      rarity: json['rarity'] as String,
      baseXp: json['baseXp'] as int,
    );
  }

  Color get rarityColor => rarityColors[rarity] ?? Colors.white70;

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
}

Bird unknownBird(String name) => Bird(
      name: name,
      scientificName: 'Species not yet in database',
      imageUrl: '',
      audioUrl: '',
      lore:
          'You found something we\'ve never seen before! This species isn\'t in our database yet. '
          'Your discovery has been logged and will help us grow AviQuest.',
      habitat: 'Unknown',
      conservationStatus: 'Unknown',
      rarity: 'unknown',
      baseXp: 100,
    );
