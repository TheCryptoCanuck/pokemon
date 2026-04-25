/// Status of a lost dog report.
enum LostDogStatus {
  active,
  found,
  cancelled;

  String get label {
    switch (this) {
      case LostDogStatus.active:
        return 'Missing';
      case LostDogStatus.found:
        return 'Reunited';
      case LostDogStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Confidence level for a stray-to-lost match.
enum MatchConfidence {
  high,
  medium,
  low;

  String get label {
    switch (this) {
      case MatchConfidence.high:
        return 'Likely Match';
      case MatchConfidence.medium:
        return 'Possible Match';
      case MatchConfidence.low:
        return 'Weak Match';
    }
  }
}

/// A report that a dog is missing, with its visual embedding for matching.
class LostDogReport {
  final String id;
  final String dogName;
  final String? breed;
  final String? photoPath;
  final List<double> embedding;
  final double? lastSeenLat;
  final double? lastSeenLon;
  final String? lastSeenLocation;
  final DateTime lostDate;
  final DateTime createdAt;
  final LostDogStatus status;
  final String? ownerContact;
  final String? notes;

  const LostDogReport({
    required this.id,
    required this.dogName,
    this.breed,
    this.photoPath,
    this.embedding = const [],
    this.lastSeenLat,
    this.lastSeenLon,
    this.lastSeenLocation,
    required this.lostDate,
    required this.createdAt,
    this.status = LostDogStatus.active,
    this.ownerContact,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'dogName': dogName,
        'breed': breed,
        'photoPath': photoPath,
        'embedding': embedding,
        'lastSeenLat': lastSeenLat,
        'lastSeenLon': lastSeenLon,
        'lastSeenLocation': lastSeenLocation,
        'lostDate': lostDate.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'ownerContact': ownerContact,
        'notes': notes,
      };

  factory LostDogReport.fromJson(Map<String, dynamic> json) => LostDogReport(
        id: json['id'] as String? ?? '',
        dogName: json['dogName'] as String? ?? '',
        breed: json['breed'] as String?,
        photoPath: json['photoPath'] as String?,
        embedding: (json['embedding'] as List<dynamic>?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            [],
        lastSeenLat: (json['lastSeenLat'] as num?)?.toDouble(),
        lastSeenLon: (json['lastSeenLon'] as num?)?.toDouble(),
        lastSeenLocation: json['lastSeenLocation'] as String?,
        lostDate: DateTime.tryParse(json['lostDate'] as String? ?? '') ??
            DateTime.now(),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        status: LostDogStatus.values.firstWhere(
          (s) => s.name == (json['status'] as String?),
          orElse: () => LostDogStatus.active,
        ),
        ownerContact: json['ownerContact'] as String?,
        notes: json['notes'] as String?,
      );

  LostDogReport copyWith({
    String? dogName,
    String? breed,
    String? photoPath,
    List<double>? embedding,
    double? lastSeenLat,
    double? lastSeenLon,
    String? lastSeenLocation,
    DateTime? lostDate,
    LostDogStatus? status,
    String? ownerContact,
    String? notes,
  }) =>
      LostDogReport(
        id: id,
        dogName: dogName ?? this.dogName,
        breed: breed ?? this.breed,
        photoPath: photoPath ?? this.photoPath,
        embedding: embedding ?? this.embedding,
        lastSeenLat: lastSeenLat ?? this.lastSeenLat,
        lastSeenLon: lastSeenLon ?? this.lastSeenLon,
        lastSeenLocation: lastSeenLocation ?? this.lastSeenLocation,
        lostDate: lostDate ?? this.lostDate,
        createdAt: createdAt,
        status: status ?? this.status,
        ownerContact: ownerContact ?? this.ownerContact,
        notes: notes ?? this.notes,
      );
}

/// A potential match between a scanned stray and a lost dog report.
class LostDogMatch {
  final String reportId;
  final String dogName;
  final String? breed;
  final String? photoPath;
  final double similarity;
  final double? distanceKm;

  const LostDogMatch({
    required this.reportId,
    required this.dogName,
    this.breed,
    this.photoPath,
    required this.similarity,
    this.distanceKm,
  });

  MatchConfidence get confidence {
    if (similarity >= 0.85) return MatchConfidence.high;
    if (similarity >= 0.70) return MatchConfidence.medium;
    return MatchConfidence.low;
  }

  int get similarityPercent => (similarity * 100).round();
}

/// Result of scanning a found/stray dog.
class StrayScanResult {
  final String scanId;
  final String? photoPath;
  final DateTime scannedAt;
  final List<LostDogMatch> matches;

  const StrayScanResult({
    required this.scanId,
    this.photoPath,
    required this.scannedAt,
    this.matches = const [],
  });
}
