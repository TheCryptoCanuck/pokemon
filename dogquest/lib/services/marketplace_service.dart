import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/marketplace.dart';

final marketplaceServiceProvider =
    Provider<MarketplaceService>((ref) => MarketplaceService());

final marketplaceStatsProvider = Provider<MarketplaceStats>(
    (ref) => ref.watch(marketplaceServiceProvider).stats);

final nearbyProvidersProvider = Provider<List<MarketplaceProvider>>(
    (ref) => ref.watch(marketplaceServiceProvider).nearbyProviders);

final featuredProvidersProvider = Provider<List<MarketplaceProvider>>(
    (ref) => ref.watch(marketplaceServiceProvider).featuredProviders);

/// Mock data service for the Pet Marketplace feature.
///
/// Provides 20 realistic NYC-area service providers spread across all
/// six [ServiceCategory] values, plus aspirational investor metrics.
class MarketplaceService {
  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// All available service categories.
  List<ServiceCategory> get categories => ServiceCategory.values;

  /// Providers filtered to the given [category].
  List<MarketplaceProvider> getProviders(ServiceCategory category) {
    return _providers.where((p) => p.category == category).toList();
  }

  /// Top 4 featured providers — verified first, then highest-rated.
  List<MarketplaceProvider> get featuredProviders {
    final sorted = List<MarketplaceProvider>.from(_providers)
      ..sort((a, b) {
        if (a.isVerified != b.isVerified) return a.isVerified ? -1 : 1;
        return b.rating.compareTo(a.rating);
      });
    return sorted.take(4).toList();
  }

  /// Closest 5 providers by distance.
  List<MarketplaceProvider> get nearbyProviders {
    final sorted = List<MarketplaceProvider>.from(_providers)
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return sorted.take(5).toList();
  }

  /// Look up a single provider by [id], or null if not found.
  MarketplaceProvider? getProvider(String id) {
    for (final p in _providers) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Providers whose [breedSpecializations] contain [breed] (case-insensitive).
  List<MarketplaceProvider> getRecommendedForBreed(String breed) {
    final lower = breed.toLowerCase();
    return _providers
        .where((p) =>
            p.breedSpecializations.any((s) => s.toLowerCase().contains(lower)))
        .toList();
  }

  /// Aspirational investor-facing marketplace metrics.
  MarketplaceStats get stats => const MarketplaceStats(
        totalProviders: 847,
        monthlyGMV: 125000.0,
        takeRate: 0.12,
        activeUsers: 3200,
      );

  // ---------------------------------------------------------------------------
  // Seed data — 20 realistic NYC-area providers
  // ---------------------------------------------------------------------------

  static const List<MarketplaceProvider> _providers = [
    // ── Dog Walkers (4) ─────────────────────────────────────────────────────
    MarketplaceProvider(
      id: 'dw-001',
      name: 'Central Bark Dog Walking',
      category: ServiceCategory.dogWalker,
      rating: 4.9,
      reviewCount: 312,
      priceRange: '\$20-35/walk',
      distanceKm: 0.4,
      address: '155 W 68th St, New York, NY 10023',
      description:
          'Premium off-leash group walks in Central Park with GPS tracking '
          'and photo updates after every session.',
      phone: '(212) 555-0147',
      isVerified: true,
      partnerDiscount: 15,
      breedSpecializations: [
        'Golden Retriever',
        'Labrador Retriever',
        'French Bulldog',
      ],
      tags: ['Top Rated', 'GPS Tracking'],
    ),
    MarketplaceProvider(
      id: 'dw-002',
      name: 'Brooklyn Paws Patrol',
      category: ServiceCategory.dogWalker,
      rating: 4.6,
      reviewCount: 189,
      priceRange: '\$18-30/walk',
      distanceKm: 3.2,
      address: '247 Smith St, Brooklyn, NY 11231',
      description:
          'Neighborhood walks and puppy socialization in Prospect Park. '
          'Bonded and insured with 10+ years experience.',
      phone: '(718) 555-0233',
      isVerified: false,
      breedSpecializations: [
        'Poodle',
        'Cavalier King Charles Spaniel',
        'Beagle',
      ],
      tags: ['Popular'],
    ),
    MarketplaceProvider(
      id: 'dw-003',
      name: 'Happy Tails NYC',
      category: ServiceCategory.dogWalker,
      rating: 4.3,
      reviewCount: 97,
      priceRange: '\$15-25/walk',
      distanceKm: 1.8,
      address: '410 E 9th St, New York, NY 10009',
      description: 'Solo and small-group walks through the East Village and '
          'Tompkins Square Park. Puppy specialists.',
      phone: '(212) 555-0381',
      isVerified: false,
      breedSpecializations: [
        'French Bulldog',
        'Chihuahua',
        'Yorkshire Terrier',
      ],
      tags: ['New'],
    ),

    // ── Groomers (3) ────────────────────────────────────────────────────────
    MarketplaceProvider(
      id: 'gr-001',
      name: 'Paws & Claws Grooming Studio',
      category: ServiceCategory.groomer,
      rating: 4.8,
      reviewCount: 274,
      priceRange: '\$65-120',
      distanceKm: 1.1,
      address: '89 Greenwich Ave, New York, NY 10014',
      description:
          'Full-service grooming with organic shampoos. Breed-specific cuts, '
          'nail trimming, and ear cleaning. Walk-ins welcome.',
      phone: '(212) 555-0519',
      isVerified: true,
      partnerDiscount: 10,
      breedSpecializations: [
        'Poodle',
        'Bichon Frise',
        'Shih Tzu',
        'Maltese',
      ],
      tags: ['Top Rated', 'Organic Products'],
    ),
    MarketplaceProvider(
      id: 'gr-002',
      name: 'Doggie Style Salon',
      category: ServiceCategory.groomer,
      rating: 4.5,
      reviewCount: 156,
      priceRange: '\$50-95',
      distanceKm: 2.5,
      address: '321 Atlantic Ave, Brooklyn, NY 11217',
      description:
          'Stress-free grooming with calming music and gentle handling. '
          'Specializing in anxious dogs and first-time puppies.',
      phone: '(718) 555-0644',
      isVerified: false,
      partnerDiscount: 20,
      breedSpecializations: [
        'Goldendoodle',
        'Labradoodle',
        'Cocker Spaniel',
      ],
      tags: ['Gentle Handling'],
    ),
    MarketplaceProvider(
      id: 'gr-003',
      name: 'Fur & Away Mobile Grooming',
      category: ServiceCategory.groomer,
      rating: 4.4,
      reviewCount: 83,
      priceRange: '\$80-150',
      distanceKm: 0.9,
      address: 'Mobile — serves Manhattan & Brooklyn',
      description:
          'Fully equipped grooming van comes to your door. Perfect for '
          'large breeds or dogs who get nervous at salons.',
      phone: '(917) 555-0722',
      isVerified: false,
      breedSpecializations: [
        'German Shepherd',
        'Husky',
        'Great Dane',
        'Bernese Mountain Dog',
      ],
      tags: ['Mobile Service'],
    ),

    // ── Trainers (4) ────────────────────────────────────────────────────────
    MarketplaceProvider(
      id: 'tr-001',
      name: 'NYC K9 Academy',
      category: ServiceCategory.trainer,
      rating: 4.7,
      reviewCount: 203,
      priceRange: '\$100-200/session',
      distanceKm: 2.1,
      address: '55 W 26th St, New York, NY 10010',
      description:
          'AKC-certified trainers offering puppy kindergarten, obedience, '
          'and behavior modification. Board-and-train available.',
      phone: '(212) 555-0856',
      isVerified: true,
      partnerDiscount: 15,
      breedSpecializations: [
        'German Shepherd',
        'Belgian Malinois',
        'Doberman Pinscher',
        'Rottweiler',
      ],
      tags: ['AKC Certified', 'Board & Train'],
    ),
    MarketplaceProvider(
      id: 'tr-002',
      name: 'Sit Means Sit Manhattan',
      category: ServiceCategory.trainer,
      rating: 4.4,
      reviewCount: 131,
      priceRange: '\$85-175/session',
      distanceKm: 1.5,
      address: '220 E 42nd St, New York, NY 10017',
      description: 'Positive-reinforcement training for all ages and breeds. '
          'Group classes, private sessions, and reactive dog programs.',
      phone: '(212) 555-0968',
      isVerified: false,
      breedSpecializations: [
        'Pit Bull',
        'Boxer',
        'Bulldog',
      ],
      tags: ['Positive Reinforcement'],
    ),
    MarketplaceProvider(
      id: 'tr-003',
      name: 'Urban Canine Project',
      category: ServiceCategory.trainer,
      rating: 4.2,
      reviewCount: 64,
      priceRange: '\$75-140/session',
      distanceKm: 4.0,
      address: '178 Court St, Brooklyn, NY 11201',
      description: 'City-focused training covering elevator manners, subway '
          'desensitization, and off-leash recall in urban parks.',
      phone: '(718) 555-0135',
      isVerified: false,
      breedSpecializations: [
        'Australian Shepherd',
        'Border Collie',
        'Jack Russell Terrier',
      ],
      tags: ['Urban Specialist'],
    ),

    // ── Veterinarians (4) ───────────────────────────────────────────────────
    MarketplaceProvider(
      id: 'vt-001',
      name: 'Park Avenue Veterinary',
      category: ServiceCategory.vet,
      rating: 4.8,
      reviewCount: 421,
      priceRange: '\$\$\$',
      distanceKm: 1.3,
      address: '830 Park Ave, New York, NY 10021',
      description:
          'Full-service veterinary hospital with on-site lab, digital X-ray, '
          'and dental suite. 24/7 emergency line.',
      phone: '(212) 555-1042',
      isVerified: true,
      partnerDiscount: 10,
      breedSpecializations: [
        'French Bulldog',
        'English Bulldog',
        'Pug',
      ],
      tags: ['Top Rated', '24/7 Emergency'],
    ),
    MarketplaceProvider(
      id: 'vt-002',
      name: 'Bond Vet — Union Square',
      category: ServiceCategory.vet,
      rating: 4.6,
      reviewCount: 289,
      priceRange: '\$\$',
      distanceKm: 0.7,
      address: '26 Astor Pl, New York, NY 10003',
      description:
          'Modern vet clinic with same-day appointments and transparent '
          'pricing. Wellness plans and telemedicine available.',
      phone: '(212) 555-1158',
      isVerified: true,
      breedSpecializations: [],
      tags: ['Same-Day Appointments'],
    ),
    MarketplaceProvider(
      id: 'vt-003',
      name: 'VERG Brooklyn Emergency',
      category: ServiceCategory.vet,
      rating: 4.3,
      reviewCount: 178,
      priceRange: '\$\$\$\$',
      distanceKm: 3.8,
      address: '196 4th Ave, Brooklyn, NY 11217',
      description: 'Board-certified emergency and specialty veterinarians. '
          'Orthopedic surgery, oncology, and critical care.',
      phone: '(718) 555-1273',
      isVerified: false,
      breedSpecializations: [
        'Golden Retriever',
        'Labrador Retriever',
        'German Shepherd',
      ],
      tags: ['Emergency', 'Specialty'],
    ),
    MarketplaceProvider(
      id: 'vt-004',
      name: 'Pawsitive Vet Care',
      category: ServiceCategory.vet,
      rating: 3.9,
      reviewCount: 67,
      priceRange: '\$',
      distanceKm: 5.2,
      address: '1455 Broadway, Astoria, NY 11106',
      description:
          'Affordable wellness exams, vaccinations, and preventive care. '
          'Walk-in clinic with bilingual staff.',
      phone: '(718) 555-1389',
      isVerified: false,
      breedSpecializations: [
        'Chihuahua',
        'Shih Tzu',
        'Dachshund',
      ],
      tags: ['Affordable', 'Walk-In'],
    ),

    // ── Insurance (3) ───────────────────────────────────────────────────────
    MarketplaceProvider(
      id: 'in-001',
      name: 'PetShield Insurance',
      category: ServiceCategory.insurance,
      rating: 4.5,
      reviewCount: 534,
      priceRange: '\$30-75/mo',
      distanceKm: 0.0,
      address: 'Online — petshieldinsurance.com',
      description:
          'Comprehensive accident and illness coverage with 90% reimbursement. '
          'No breed exclusions, covers hereditary conditions.',
      isVerified: true,
      partnerDiscount: 15,
      breedSpecializations: [
        'French Bulldog',
        'Cavalier King Charles Spaniel',
        'Bernese Mountain Dog',
      ],
      tags: ['Top Rated', 'No Breed Exclusions'],
    ),
    MarketplaceProvider(
      id: 'in-002',
      name: 'Pawlicy Advisor',
      category: ServiceCategory.insurance,
      rating: 4.3,
      reviewCount: 218,
      priceRange: '\$20-60/mo',
      distanceKm: 0.0,
      address: 'Online — pawlicyadvisor.com',
      description:
          'Insurance comparison marketplace that finds the best plan for your '
          'breed. Customized quotes in under 2 minutes.',
      isVerified: false,
      partnerDiscount: 10,
      breedSpecializations: [],
      tags: ['Compare Plans'],
    ),
    MarketplaceProvider(
      id: 'in-003',
      name: 'Wagmo Wellness',
      category: ServiceCategory.insurance,
      rating: 3.8,
      reviewCount: 142,
      priceRange: '\$15-45/mo',
      distanceKm: 0.0,
      address: 'Online — wagmo.io',
      description:
          'Wellness-focused coverage for routine vet visits, grooming, and '
          'dental cleanings. Submit claims via the app.',
      isVerified: false,
      breedSpecializations: [],
      tags: ['Wellness Plans'],
    ),

    // ── Pet Stores (3) ──────────────────────────────────────────────────────
    MarketplaceProvider(
      id: 'ps-001',
      name: 'The Dog Bar NYC',
      category: ServiceCategory.petStore,
      rating: 4.7,
      reviewCount: 246,
      priceRange: '\$\$',
      distanceKm: 0.6,
      address: '32 E 7th St, New York, NY 10003',
      description:
          'Curated boutique for premium dog food, treats, and accessories. '
          'Self-serve dog wash station and adoption events.',
      phone: '(212) 555-1502',
      isVerified: true,
      partnerDiscount: 20,
      breedSpecializations: [],
      tags: ['Boutique', 'Dog Wash'],
    ),
    MarketplaceProvider(
      id: 'ps-002',
      name: 'Whiskers Holistic Pet Care',
      category: ServiceCategory.petStore,
      rating: 4.4,
      reviewCount: 173,
      priceRange: '\$\$',
      distanceKm: 2.9,
      address: '235 Court St, Brooklyn, NY 11201',
      description:
          'Holistic pet store specializing in raw diets, grain-free food, '
          'and natural supplements. Nutrition consultations available.',
      phone: '(718) 555-1618',
      isVerified: false,
      breedSpecializations: [
        'German Shepherd',
        'Husky',
        'Golden Retriever',
      ],
      tags: ['Holistic', 'Raw Diet'],
    ),
    MarketplaceProvider(
      id: 'ps-003',
      name: 'Petco Union Square',
      category: ServiceCategory.petStore,
      rating: 4.0,
      reviewCount: 389,
      priceRange: '\$',
      distanceKm: 0.8,
      address: '860 Broadway, New York, NY 10003',
      description:
          'Full-service pet store with grooming, vet services, and adoption '
          'center. Price-match guarantee on all products.',
      phone: '(212) 555-1734',
      isVerified: false,
      breedSpecializations: [],
      tags: ['Price Match'],
    ),
  ];
}
