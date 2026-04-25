import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/pack.dart';

/// Persists the user's Pack (family group) to Hive.
class PackService {
  final Box _box;
  static const _key = 'pack_data';

  PackService(this._box);

  /// The user's pack, or null if they haven't created one.
  Pack? get pack {
    final raw = _box.get(_key) as String?;
    if (raw == null || raw.isEmpty) return null;
    return Pack.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  bool get hasPack => pack != null;

  /// Create a new pack.
  void createPack(Pack p) => _save(p);

  /// Update the pack.
  void updatePack(Pack p) => _save(p);

  /// Add a member to the pack.
  void addMember(PackMember member) {
    final p = pack;
    if (p == null) return;
    final members = List<PackMember>.from(p.members)..add(member);
    _save(p.copyWith(members: members));
  }

  /// Remove a member by name.
  void removeMember(String name) {
    final p = pack;
    if (p == null) return;
    final members = List<PackMember>.from(p.members)
      ..removeWhere((m) => m.name == name);
    _save(p.copyWith(members: members));
  }

  /// Update a specific member.
  void updateMember(String originalName, PackMember updated) {
    final p = pack;
    if (p == null) return;
    final members = List<PackMember>.from(p.members);
    final idx = members.indexWhere((m) => m.name == originalName);
    if (idx >= 0) {
      members[idx] = updated;
      _save(p.copyWith(members: members));
    }
  }

  /// Record weekly activity (breeds found, XP earned).
  void recordWeeklyActivity({int breeds = 0, int xp = 0}) {
    final p = pack;
    if (p == null) return;

    final now = DateTime.now();
    final weekStart = _weekStartKey(now);

    // Reset weekly stats if new week
    if (p.weeklyStartDate != weekStart) {
      _save(p.copyWith(
        weeklyBreedsFound: breeds,
        weeklyXpEarned: xp,
        weeklyActiveDays: 1,
        weeklyStartDate: weekStart,
      ));
    } else {
      _save(p.copyWith(
        weeklyBreedsFound: p.weeklyBreedsFound + breeds,
        weeklyXpEarned: p.weeklyXpEarned + xp,
      ));
    }
  }

  /// Increment active days for the week (call once per day).
  void recordActiveDay() {
    final p = pack;
    if (p == null) return;

    final now = DateTime.now();
    final weekStart = _weekStartKey(now);
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final lastActiveDay = _box.get('pack_last_active_day') as String?;

    if (lastActiveDay == todayKey) return; // Already recorded today

    _box.put('pack_last_active_day', todayKey);

    if (p.weeklyStartDate != weekStart) {
      _save(p.copyWith(
        weeklyActiveDays: 1,
        weeklyStartDate: weekStart,
      ));
    } else {
      _save(p.copyWith(weeklyActiveDays: p.weeklyActiveDays + 1));
    }
  }

  /// Delete the pack entirely.
  void deletePack() {
    _box.delete(_key);
    _box.delete('pack_last_active_day');
  }

  void _save(Pack p) {
    _box.put(_key, jsonEncode(p.toJson()));
  }

  /// Get the Monday of the current week as a date key.
  String _weekStartKey(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }
}

final packServiceProvider = Provider<PackService>((ref) {
  throw UnimplementedError(
      'packServiceProvider must be overridden after Hive init');
});
