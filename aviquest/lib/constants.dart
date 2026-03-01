import 'package:flutter/material.dart';

// ─── Rarity Enum ──────────────────────────────────────────────────────────────

enum Rarity {
  common,
  uncommon,
  rare,
  legendary,
  unknown;

  Color get color => _rarityColors[this]!;

  String get label => this == unknown ? 'NEW DISCOVERY' : name.toUpperCase();
}

const _rarityColors = <Rarity, Color>{
  Rarity.common: Colors.white70,
  Rarity.uncommon: Color(0xFF4CAF50),
  Rarity.rare: Color(0xFF2196F3),
  Rarity.legendary: Colors.amber,
  Rarity.unknown: Color(0xFFCE93D8),
};

// ─── Theme Colors ─────────────────────────────────────────────────────────────

const bgDeep = Color(0xFF0A1F0F);
const bgCard = Color(0xFF1A2F1F);
const bgNav = Color(0xFF0F2A1F);
