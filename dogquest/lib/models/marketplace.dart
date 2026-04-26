/// Categories of pet services available in the marketplace.
enum ServiceCategory {
  dogWalker(
    label: 'Dog Walker',
    iconName: 'directions_walk',
    colorHex: 0xFF4CAF50,
  ),
  groomer(
    label: 'Groomer',
    iconName: 'content_cut',
    colorHex: 0xFF9C27B0,
  ),
  trainer(
    label: 'Trainer',
    iconName: 'school',
    colorHex: 0xFFFF9800,
  ),
  vet(
    label: 'Veterinarian',
    iconName: 'local_hospital',
    colorHex: 0xFFF44336,
  ),
  insurance(
    label: 'Insurance',
    iconName: 'shield',
    colorHex: 0xFF2196F3,
  ),
  petStore(
    label: 'Pet Store',
    iconName: 'store',
    colorHex: 0xFF795548,
  );

  const ServiceCategory({
    required this.label,
    required this.iconName,
    required this.colorHex,
  });

  /// Human-readable display name.
  final String label;

  /// Material icon name for runtime IconData mapping.
  final String iconName;

  /// ARGB color value (e.g. 0xFF4CAF50 for green).
  final int colorHex;
}

/// A service provider listed in the marketplace.
class MarketplaceProvider {
  final String id;
  final String name;
  final ServiceCategory category;
  final double rating;
  final int reviewCount;
  final String priceRange;
  final double distanceKm;
  final String address;
  final String description;
  final String? photoUrl;
  final String? phone;
  final bool isVerified;

  /// Partner discount percentage (e.g. 15 means 15% off).
  final int? partnerDiscount;

  /// Breed names this provider specializes in.
  final List<String> breedSpecializations;

  /// Display tags such as "Top Rated", "New", "Popular".
  final List<String> tags;

  const MarketplaceProvider({
    required this.id,
    required this.name,
    required this.category,
    required this.rating,
    required this.reviewCount,
    required this.priceRange,
    required this.distanceKm,
    required this.address,
    required this.description,
    this.photoUrl,
    this.phone,
    this.isVerified = false,
    this.partnerDiscount,
    this.breedSpecializations = const [],
    this.tags = const [],
  });

  /// Whether this provider offers a DogQuest partner discount.
  bool get hasDiscount => partnerDiscount != null && partnerDiscount! > 0;

  /// Formatted discount string for display (e.g. "15% off").
  String get discountLabel => hasDiscount ? '$partnerDiscount% off' : '';

  /// Star rating clamped to 0.0 - 5.0 for safe rendering.
  double get clampedRating => rating.clamp(0.0, 5.0);
}

/// Aggregate marketplace metrics for investor dashboards.
class MarketplaceStats {
  /// Total number of listed service providers.
  final int totalProviders;

  /// Monthly gross merchandise volume in USD.
  final double monthlyGMV;

  /// Platform take rate as a fraction (e.g. 0.12 for 12%).
  final double takeRate;

  /// Monthly active users who engaged with marketplace.
  final int activeUsers;

  const MarketplaceStats({
    required this.totalProviders,
    required this.monthlyGMV,
    required this.takeRate,
    required this.activeUsers,
  });

  /// Monthly net revenue (GMV * take rate).
  double get monthlyRevenue => monthlyGMV * takeRate;

  /// Average GMV per active user.
  double get gmvPerUser => activeUsers > 0 ? monthlyGMV / activeUsers : 0.0;
}
