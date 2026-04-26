import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dogquest/constants.dart';
import 'package:dogquest/models/marketplace.dart';
import 'package:dogquest/services/marketplace_service.dart';

/// Detail view for a single marketplace service provider.
class ProviderDetailScreen extends ConsumerWidget {
  final String providerId;

  const ProviderDetailScreen({super.key, required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marketplaceSvc = ref.read(marketplaceServiceProvider);
    final provider = marketplaceSvc.getProvider(providerId);

    if (provider == null) {
      return Scaffold(
        backgroundColor: bgDeep,
        appBar: AppBar(
          backgroundColor: bgCard,
          foregroundColor: textPrimary,
        ),
        body: const Center(
          child: Text(
            'Provider not found.',
            style: TextStyle(color: textSecondary),
          ),
        ),
      );
    }

    final categoryColor = Color(provider.category.colorHex);

    return Scaffold(
      backgroundColor: bgDeep,
      body: CustomScrollView(
        slivers: [
          // ── App bar ─────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: bgCard,
            foregroundColor: textPrimary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      categoryColor.withValues(alpha: 0.3),
                      bgDeep,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 32),
                        // Provider avatar circle
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: categoryColor.withValues(alpha: 0.2),
                          child: Text(
                            provider.name.isNotEmpty
                                ? provider.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: categoryColor,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Category chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: categoryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            provider.category.label,
                            style: TextStyle(
                              color: categoryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      provider.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  if (provider.isVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified,
                      color: Colors.blueAccent,
                      size: 18,
                    ),
                  ],
                ],
              ),
              centerTitle: true,
            ),
          ),

          // ── Body content ────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Rating section
                _RatingSection(provider: provider)
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.05, end: 0, duration: 400.ms),

                const SizedBox(height: 20),

                // About
                const _SectionTitle(title: 'About')
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 100.ms),
                const SizedBox(height: 8),
                Text(
                  provider.description,
                  style: TextStyle(
                    color: textSecondary.withValues(alpha: 0.85),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 150.ms),

                const SizedBox(height: 20),

                // Info rows
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: provider.address,
                ).animate().fadeIn(duration: 300.ms, delay: 200.ms),
                if (provider.phone != null) ...[
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.phone_outlined,
                    label: provider.phone!,
                  ).animate().fadeIn(duration: 300.ms, delay: 250.ms),
                ],
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.near_me_outlined,
                  label: '${provider.distanceKm.toStringAsFixed(1)} km away',
                ).animate().fadeIn(duration: 300.ms, delay: 300.ms),

                // Breed specializations
                if (provider.breedSpecializations.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const _SectionTitle(title: 'Breed Specializations')
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 350.ms),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: provider.breedSpecializations
                        .map(
                          (breed) => Chip(
                            label: Text(
                              breed,
                              style: const TextStyle(
                                color: textPrimary,
                                fontSize: 12,
                              ),
                            ),
                            backgroundColor: accent.withValues(alpha: 0.15),
                            side: BorderSide(
                              color: accent.withValues(alpha: 0.3),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                          ),
                        )
                        .toList(),
                  ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
                ],

                // Partner discount box
                if (provider.hasDiscount) ...[
                  const SizedBox(height: 24),
                  _PartnerDiscountBox(
                    discountPercent: provider.partnerDiscount!,
                  ).animate().fadeIn(duration: 500.ms, delay: 450.ms).shimmer(
                        duration: 1500.ms,
                        delay: 950.ms,
                        color: Colors.amber.withValues(alpha: 0.15),
                      ),
                ],

                const SizedBox(height: 28),

                // Book Now button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Coming soon!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: bgDeep,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('Book Now'),
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 500.ms).slideY(
                      begin: 0.1,
                      end: 0,
                      duration: 400.ms,
                      delay: 500.ms,
                    ),

                const SizedBox(height: 28),

                // Reviews section
                const _SectionTitle(title: 'Reviews')
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 550.ms),
                const SizedBox(height: 12),
                ..._mockReviews.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ReviewCard(review: entry.value)
                            .animate()
                            .fadeIn(
                              duration: 300.ms,
                              delay: (600 + entry.key * 80).ms,
                            )
                            .slideX(
                              begin: 0.05,
                              end: 0,
                              duration: 300.ms,
                              delay: (600 + entry.key * 80).ms,
                            ),
                      ),
                    ),

                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Rating section ────────────────────────────────────────────────────────────

class _RatingSection extends StatelessWidget {
  final MarketplaceProvider provider;

  const _RatingSection({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Big star rating
          Column(
            children: [
              Row(
                children: List.generate(5, (i) {
                  final filled = i < provider.clampedRating.floor();
                  final half = i == provider.clampedRating.floor() &&
                      provider.clampedRating % 1 >= 0.5;
                  return Icon(
                    half
                        ? Icons.star_half_rounded
                        : filled
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                    color: Colors.amber,
                    size: 24,
                  );
                }),
              ),
              const SizedBox(height: 6),
              Text(
                '${provider.clampedRating.toStringAsFixed(1)} out of 5',
                style: TextStyle(
                  color: textSecondary.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${provider.reviewCount} reviews',
                style: const TextStyle(
                  color: textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                provider.priceRange,
                style: const TextStyle(
                  color: accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Section title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: accent, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: textSecondary, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

// ── Partner discount box ─────────────────────────────────────────────────────

class _PartnerDiscountBox extends StatelessWidget {
  final int discountPercent;

  const _PartnerDiscountBox({required this.discountPercent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withValues(alpha: 0.2),
            Colors.amber.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_offer_rounded,
              color: Colors.amber,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Partner Discount',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'DogQuest Members save $discountPercent%!',
                  style: TextStyle(
                    color: Colors.amber.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mock reviews ─────────────────────────────────────────────────────────────

class _MockReview {
  final String author;
  final double rating;
  final String text;
  final String timeAgo;

  const _MockReview({
    required this.author,
    required this.rating,
    required this.text,
    required this.timeAgo,
  });
}

const _mockReviews = [
  _MockReview(
    author: 'Sarah M.',
    rating: 5.0,
    text:
        'Absolutely wonderful experience! My Golden Retriever loved every minute. '
        'Will definitely be coming back.',
    timeAgo: '2 days ago',
  ),
  _MockReview(
    author: 'James K.',
    rating: 4.5,
    text:
        'Very professional and knowledgeable. Great with my anxious rescue pup. '
        'Only wish they had weekend availability.',
    timeAgo: '1 week ago',
  ),
  _MockReview(
    author: 'Linda P.',
    rating: 5.0,
    text: 'The DogQuest partner discount is a great perk! '
        'Excellent service and my Labrador always comes home happy.',
    timeAgo: '2 weeks ago',
  ),
];

class _ReviewCard extends StatelessWidget {
  final _MockReview review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: accent.withValues(alpha: 0.2),
                child: Text(
                  review.author[0],
                  style: const TextStyle(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  review.author,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                review.timeAgo,
                style: TextStyle(
                  color: textSecondary.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Stars
          Row(
            children: List.generate(5, (i) {
              final filled = i < review.rating.floor();
              final half =
                  i == review.rating.floor() && review.rating % 1 >= 0.5;
              return Icon(
                half
                    ? Icons.star_half_rounded
                    : filled
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                color: Colors.amber,
                size: 16,
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            review.text,
            style: TextStyle(
              color: textSecondary.withValues(alpha: 0.85),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
