import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dogquest/constants.dart';
import 'package:dogquest/models/marketplace.dart';
import 'package:dogquest/services/marketplace_service.dart';

class MarketplaceScreen extends ConsumerWidget {
  const MarketplaceScreen({super.key});

  static const _categoryIcons = <ServiceCategory, IconData>{
    ServiceCategory.dogWalker: Icons.directions_walk,
    ServiceCategory.groomer: Icons.content_cut,
    ServiceCategory.trainer: Icons.school,
    ServiceCategory.vet: Icons.local_hospital,
    ServiceCategory.insurance: Icons.shield,
    ServiceCategory.petStore: Icons.store,
  };

  static const _categoryProviderCounts = <ServiceCategory, int>{
    ServiceCategory.dogWalker: 214,
    ServiceCategory.groomer: 186,
    ServiceCategory.trainer: 127,
    ServiceCategory.vet: 156,
    ServiceCategory.insurance: 43,
    ServiceCategory.petStore: 121,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(marketplaceStatsProvider);
    final nearbyProviders = ref.watch(nearbyProvidersProvider);
    final featuredProviders = ref.watch(featuredProvidersProvider);

    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AppBar(
        backgroundColor: bgDeep,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_bag, color: accent, size: 22),
            SizedBox(width: 8),
            Text(
              'Pet Marketplace',
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // -- Investor Metrics Banner --
          _InvestorMetricsBanner(stats: stats)
              .animate()
              .fadeIn(duration: 400.ms, delay: 100.ms)
              .slideY(begin: -0.1, end: 0),

          const SizedBox(height: 20),

          // -- Near You Section --
          const _SectionHeader(title: 'Near You', icon: Icons.near_me)
              .animate()
              .fadeIn(duration: 400.ms, delay: 200.ms),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: nearbyProviders.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final provider = nearbyProviders[index];
                return _NearbyProviderCard(
                  provider: provider,
                  icon: _categoryIcons[provider.category] ?? Icons.pets,
                )
                    .animate()
                    .fadeIn(duration: 350.ms, delay: (250 + index * 80).ms)
                    .slideX(begin: 0.15, end: 0);
              },
            ),
          ),

          const SizedBox(height: 28),

          // -- Category Grid --
          const _SectionHeader(
            title: 'Browse Categories',
            icon: Icons.grid_view,
          ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.0,
              children: ServiceCategory.values.asMap().entries.map((entry) {
                final index = entry.key;
                final category = entry.value;
                return _CategoryTile(
                  category: category,
                  icon: _categoryIcons[category] ?? Icons.pets,
                  count: _categoryProviderCounts[category] ?? 0,
                )
                    .animate()
                    .fadeIn(duration: 350.ms, delay: (450 + index * 60).ms)
                    .scale(
                      begin: const Offset(0.9, 0.9),
                      end: const Offset(1, 1),
                    );
              }).toList(),
            ),
          ),

          const SizedBox(height: 28),

          // -- Featured Partners --
          const _SectionHeader(title: 'Featured Partners', icon: Icons.star)
              .animate()
              .fadeIn(duration: 400.ms, delay: 650.ms),
          const SizedBox(height: 12),
          ...featuredProviders.take(4).toList().asMap().entries.map((entry) {
            final index = entry.key;
            final provider = entry.value;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _FeaturedProviderCard(
                provider: provider,
                icon: _categoryIcons[provider.category] ?? Icons.pets,
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: (700 + index * 100).ms)
                  .slideY(begin: 0.1, end: 0),
            );
          }),

          const SizedBox(height: 16),

          // -- Become a Partner CTA --
          _PartnerCTA()
              .animate()
              .fadeIn(duration: 500.ms, delay: 1100.ms)
              .slideY(begin: 0.15, end: 0),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Investor Metrics Banner
// ---------------------------------------------------------------------------

class _InvestorMetricsBanner extends StatelessWidget {
  final MarketplaceStats stats;
  const _InvestorMetricsBanner({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MetricPill(
            value: '${stats.totalProviders}',
            label: 'Providers',
          ),
          Container(
            width: 1,
            height: 28,
            color: Colors.amber.withValues(alpha: 0.2),
          ),
          _MetricPill(
            value: '\$${(stats.monthlyGMV / 1000).toStringAsFixed(0)}K',
            label: 'Monthly GMV',
          ),
          Container(
            width: 1,
            height: 28,
            color: Colors.amber.withValues(alpha: 0.2),
          ),
          _MetricPill(
            value: '${(stats.takeRate * 100).toStringAsFixed(0)}%',
            label: 'Take Rate',
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String value;
  final String label;
  const _MetricPill({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.amber,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.amber.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section Header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nearby Provider Card (horizontal scroll)
// ---------------------------------------------------------------------------

class _NearbyProviderCard extends StatelessWidget {
  final MarketplaceProvider provider;
  final IconData icon;
  const _NearbyProviderCard({required this.provider, required this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/marketplace/provider/${provider.id}');
      },
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: provider.isVerified
                ? accent.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon + category
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(provider.category.colorHex)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: Color(provider.category.colorHex),
                    size: 20,
                  ),
                ),
                const Spacer(),
                if (provider.isVerified)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Verified',
                      style: TextStyle(
                        color: accent,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Name
            Text(
              provider.name,
              style: const TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // Rating stars
            Row(
              children: [
                ...List.generate(5, (i) {
                  return Icon(
                    i < provider.clampedRating.round()
                        ? Icons.star
                        : Icons.star_border,
                    color: Colors.amber,
                    size: 14,
                  );
                }),
                const SizedBox(width: 4),
                Text(
                  provider.clampedRating.toStringAsFixed(1),
                  style: TextStyle(
                    color: Colors.amber.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Distance
            Row(
              children: [
                const Icon(Icons.location_on, color: textSecondary, size: 13),
                const SizedBox(width: 3),
                Text(
                  '${provider.distanceKm.toStringAsFixed(1)} km',
                  style: const TextStyle(color: textSecondary, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category Tile (grid)
// ---------------------------------------------------------------------------

class _CategoryTile extends StatelessWidget {
  final ServiceCategory category;
  final IconData icon;
  final int count;
  const _CategoryTile({
    required this.category,
    required this.icon,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(category.colorHex);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/marketplace/category/${category.name}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              category.label,
              style: const TextStyle(
                color: textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '$count providers',
              style: TextStyle(
                color: textSecondary.withValues(alpha: 0.6),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Featured Provider Card (vertical list)
// ---------------------------------------------------------------------------

class _FeaturedProviderCard extends StatelessWidget {
  final MarketplaceProvider provider;
  final IconData icon;
  const _FeaturedProviderCard({required this.provider, required this.icon});

  @override
  Widget build(BuildContext context) {
    final catColor = Color(provider.category.colorHex);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/marketplace/provider/${provider.id}');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: provider.isVerified
                ? accent.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            // Category icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: catColor, size: 26),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + category label
                  Text(
                    provider.name,
                    style: const TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    provider.category.label,
                    style: TextStyle(
                      color: catColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Rating + price
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        provider.clampedRating.toStringAsFixed(1),
                        style:
                            const TextStyle(color: textPrimary, fontSize: 13),
                      ),
                      Text(
                        ' (${provider.reviewCount})',
                        style:
                            const TextStyle(color: textSecondary, fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        provider.priceRange,
                        style: TextStyle(
                          color: Colors.green.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Badges column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (provider.hasDiscount)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '${provider.partnerDiscount}% Off',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (provider.isVerified)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, color: accent, size: 12),
                        SizedBox(width: 3),
                        Text(
                          'Verified',
                          style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Partner CTA Banner
// ---------------------------------------------------------------------------

class _PartnerCTA extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.12),
            Colors.amber.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.business_center, color: accent, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Become a Hound Partner',
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Reach thousands of local dog owners. Apply today.',
                  style: TextStyle(
                    color: textSecondary.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            color: accent.withValues(alpha: 0.6),
            size: 16,
          ),
        ],
      ),
    );
  }
}
