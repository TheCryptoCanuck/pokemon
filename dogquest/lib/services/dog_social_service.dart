import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';

final _log = Logger('DogSocialService');

/// Social profile for a dog — extends the breed/sighting data with social features.
class DogSocialProfile {
  final String dogName;
  final String breed;
  final String? photoPath;
  final String bio;
  final List<String> personalityTags;
  final int followerCount;
  final int followingCount;
  final List<String> photoGallery; // local file paths
  final DateTime createdAt;
  final bool isFollowed; // whether current user follows this dog

  const DogSocialProfile({
    required this.dogName,
    required this.breed,
    this.photoPath,
    this.bio = '',
    this.personalityTags = const [],
    this.followerCount = 0,
    this.followingCount = 0,
    this.photoGallery = const [],
    required this.createdAt,
    this.isFollowed = false,
  });

  Map<String, dynamic> toJson() => {
    'dogName': dogName,
    'breed': breed,
    'photoPath': photoPath,
    'bio': bio,
    'personalityTags': personalityTags,
    'followerCount': followerCount,
    'followingCount': followingCount,
    'photoGallery': photoGallery,
    'createdAt': createdAt.toIso8601String(),
    'isFollowed': isFollowed,
  };

  factory DogSocialProfile.fromJson(Map<String, dynamic> json) => DogSocialProfile(
    dogName: json['dogName'] as String? ?? '',
    breed: json['breed'] as String? ?? '',
    photoPath: json['photoPath'] as String?,
    bio: json['bio'] as String? ?? '',
    personalityTags: (json['personalityTags'] as List<dynamic>?)?.cast<String>() ?? [],
    followerCount: json['followerCount'] as int? ?? 0,
    followingCount: json['followingCount'] as int? ?? 0,
    photoGallery: (json['photoGallery'] as List<dynamic>?)?.cast<String>() ?? [],
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    isFollowed: json['isFollowed'] as bool? ?? false,
  );

  DogSocialProfile copyWith({
    String? bio,
    List<String>? personalityTags,
    int? followerCount,
    int? followingCount,
    List<String>? photoGallery,
    bool? isFollowed,
  }) => DogSocialProfile(
    dogName: dogName,
    breed: breed,
    photoPath: photoPath,
    bio: bio ?? this.bio,
    personalityTags: personalityTags ?? this.personalityTags,
    followerCount: followerCount ?? this.followerCount,
    followingCount: followingCount ?? this.followingCount,
    photoGallery: photoGallery ?? this.photoGallery,
    createdAt: createdAt,
    isFollowed: isFollowed ?? this.isFollowed,
  );
}

/// Activity feed item — represents a social event.
class FeedItem {
  final String id;
  final String dogName;
  final String breed;
  final String type; // 'sighting', 'new_friend', 'level_up', 'achievement', 'photo'
  final String text;
  final String? photoPath;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;

  const FeedItem({
    required this.id,
    required this.dogName,
    required this.breed,
    required this.type,
    required this.text,
    this.photoPath,
    required this.timestamp,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'dogName': dogName,
    'breed': breed,
    'type': type,
    'text': text,
    'photoPath': photoPath,
    'timestamp': timestamp.toIso8601String(),
    if (latitude != null) 'lat': latitude,
    if (longitude != null) 'lon': longitude,
  };

  factory FeedItem.fromJson(Map<String, dynamic> json) => FeedItem(
    id: json['id'] as String? ?? '',
    dogName: json['dogName'] as String? ?? '',
    breed: json['breed'] as String? ?? '',
    type: json['type'] as String? ?? 'sighting',
    text: json['text'] as String? ?? '',
    photoPath: json['photoPath'] as String?,
    timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    latitude: (json['lat'] as num?)?.toDouble(),
    longitude: (json['lon'] as num?)?.toDouble(),
  );
}

/// Manages dog social profiles, following, and the activity feed.
/// All local-first using Hive.
class DogSocialService {
  final Box _box;
  static const _profilesKey = 'dog_social_profiles';
  static const _followingKey = 'dog_following'; // Set of dog names we follow
  static const _feedKey = 'dog_feed_items';

  DogSocialService(this._box);

  // ─── Profiles ───────────────────────────────────────────────

  /// Get or create a social profile for a dog.
  DogSocialProfile? getProfile(String dogName) {
    final profiles = _loadProfiles();
    return profiles[dogName];
  }

  /// Get all social profiles.
  List<DogSocialProfile> get allProfiles => _loadProfiles().values.toList();

  /// Save/update a dog's social profile.
  void saveProfile(DogSocialProfile profile) {
    final profiles = _loadProfiles();
    profiles[profile.dogName] = profile;
    _saveProfiles(profiles);
  }

  /// Update bio for a dog profile.
  void updateBio(String dogName, String bio) {
    final profiles = _loadProfiles();
    final existing = profiles[dogName];
    if (existing != null) {
      profiles[dogName] = existing.copyWith(bio: bio);
      _saveProfiles(profiles);
    }
  }

  /// Add a photo to a dog's gallery.
  void addPhoto(String dogName, String photoPath) {
    final profiles = _loadProfiles();
    final existing = profiles[dogName];
    if (existing != null) {
      final gallery = List<String>.from(existing.photoGallery);
      gallery.insert(0, photoPath); // newest first
      if (gallery.length > 20) gallery.removeLast(); // cap at 20
      profiles[dogName] = existing.copyWith(photoGallery: gallery);
      _saveProfiles(profiles);
    }
  }

  Map<String, DogSocialProfile> _loadProfiles() {
    final raw = _box.get(_profilesKey) as String?;
    if (raw == null || raw.isEmpty) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, DogSocialProfile.fromJson(v as Map<String, dynamic>)));
  }

  void _saveProfiles(Map<String, DogSocialProfile> profiles) {
    _box.put(_profilesKey, jsonEncode(profiles.map((k, v) => MapEntry(k, v.toJson()))));
  }

  // ─── Following ──────────────────────────────────────────────

  /// Follow a dog.
  void follow(String dogName) {
    final following = _loadFollowing();
    following.add(dogName);
    _saveFollowing(following);
    _log.info('Now following: $dogName');
  }

  /// Unfollow a dog.
  void unfollow(String dogName) {
    final following = _loadFollowing();
    following.remove(dogName);
    _saveFollowing(following);
    _log.info('Unfollowed: $dogName');
  }

  /// Check if we follow a dog.
  bool isFollowing(String dogName) => _loadFollowing().contains(dogName);

  /// Get all followed dog names.
  Set<String> get following => _loadFollowing();

  /// Number of dogs we follow.
  int get followingCount => _loadFollowing().length;

  Set<String> _loadFollowing() {
    final raw = _box.get(_followingKey) as String?;
    if (raw == null || raw.isEmpty) return {};
    return Set<String>.from(jsonDecode(raw) as List);
  }

  void _saveFollowing(Set<String> following) {
    _box.put(_followingKey, jsonEncode(following.toList()));
  }

  // ─── Activity Feed ──────────────────────────────────────────

  /// Add a feed item.
  void addFeedItem(FeedItem item) {
    final feed = _loadFeed();
    feed.insert(0, item);
    if (feed.length > 100) feed.removeRange(100, feed.length); // cap at 100
    _saveFeed(feed);
  }

  /// Get feed items, optionally filtered to followed dogs only.
  List<FeedItem> getFeed({bool followedOnly = false, int limit = 50}) {
    final feed = _loadFeed();
    if (!followedOnly) return feed.take(limit).toList();
    final followedDogs = _loadFollowing();
    return feed.where((item) => followedDogs.contains(item.dogName)).take(limit).toList();
  }

  /// Get feed items for a specific dog.
  List<FeedItem> feedForDog(String dogName) {
    return _loadFeed().where((item) => item.dogName == dogName).toList();
  }

  List<FeedItem> _loadFeed() {
    final raw = _box.get(_feedKey) as String?;
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => FeedItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  void _saveFeed(List<FeedItem> feed) {
    _box.put(_feedKey, jsonEncode(feed.map((f) => f.toJson()).toList()));
  }

  // ─── Breed Community Stats ──────────────────────────────────

  /// Get breed community stats (how many dogs of this breed in the network).
  /// Since local-first, uses neighborhood dogs + sightings as the "community".
  Map<String, int> breedPopularity() {
    final profiles = _loadProfiles();
    final counts = <String, int>{};
    for (final p in profiles.values) {
      counts[p.breed] = (counts[p.breed] ?? 0) + 1;
    }
    return counts;
  }
}

final dogSocialServiceProvider = Provider<DogSocialService>((ref) {
  throw UnimplementedError('dogSocialServiceProvider must be overridden after Hive init');
});
