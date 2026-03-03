import 'package:flutter/material.dart';
import 'dart:math';

const bgDeep = Color(0xFF0A1F0F);
const bgCard = Color(0xFF1A2F1F);
const bgNav = Color(0xFF0F2A1F);

const achievements = {
  'first_bird': ('🐦', 'First Feather', 'Identify your first bird'),
  'five_species': ('🌿', 'Nature Curious', 'Collect 5 different species'),
  'ten_species': ('🏆', 'Avid Birder', 'Collect 10 different species'),
  'twenty_species': ('🦅', 'Wing Watcher', 'Collect 20 different species'),
  'rare_find': ('💎', 'Rare Encounter', 'Identify a rare bird'),
  'legendary_find': ('✨', 'Legend Spotter', 'Identify a legendary bird'),
  'level_5': ('⭐', 'Rising Birder', 'Reach level 5'),
  'level_10': ('🌟', 'Expert Nester', 'Reach level 10'),
  'level_20': ('🌠', 'Sky Master', 'Reach level 20'),
};

String levelTitle(int level) {
  if (level < 3) return 'Fledgling';
  if (level < 6) return 'Nestling';
  if (level < 10) return 'Sparrow';
  if (level < 15) return 'Warbler';
  if (level < 20) return 'Songweaver';
  if (level < 30) return 'Falconer';
  if (level < 40) return 'Eagle Scout';
  return 'Master Birder';
}

int xpForNextLevel(int level) => (1000 * pow(level, 1.4)).round();
