import 'package:flutter/material.dart';
import '../constants.dart';

class Bird {
  final String name;
  final String scientificName;
  final String imageUrl;
  final String audioUrl;
  final String lore;
  final String habitat;
  final String conservationStatus;
  final String rarity; // 'common' | 'uncommon' | 'rare' | 'legendary'
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

  Color get rarityColor => rarityColors[rarity] ?? Colors.white70;

  int get xp {
    switch (rarity) {
      case 'uncommon': return (baseXp * 1.5).round();
      case 'rare': return baseXp * 2;
      case 'legendary': return baseXp * 5;
      default: return baseXp;
    }
  }
}
