import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dogquest/constants.dart';
import 'package:dogquest/models/marketplace.dart';
import 'package:dogquest/services/marketplace_service.dart';

/// Lists all service providers in a given [ServiceCategory].
///
/// The [categoryName] must match a [ServiceCategory] enum name
/// (e.g. "dogWalker", "groomer").
class ServiceListScreen extends ConsumerStatefulWidget {
  final String categoryName;

  const ServiceListScreen({super.key, required this.categoryName});

  @override
  ConsumerState<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends ConsumerState<ServiceListScreen> {
  String _activeFilter = 'All';

  static const _filters = ['All', 'Top Rated', 'Nearest', 'Verified'];

  ServiceCategory? get _category {
    try {
      return ServiceCategory.values.firstWhere(
        (c) => c.name == widget.categoryName,
      );
    } catch (_) {
      return null;
    }
  }

  List<MarketplaceProvider> _sortedProviders(
    List<MarketplaceProvider> providers,
  ) {
    final sorted = List<MarketplaceProvider>.from(providers);
    switch (_activeFilter) {
      case 'Top Rated':
        sorted.sort((a, b) => b.rating.compareTo(a.rating));
      case 'Nearest':
        sorted.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      case 'Verified':
        sorted.sort((a, b) {
          if (a.isVerified == b.isVerified) return 0;
          return a.isVerified ? -1 : 1;
        });
      default:
        break;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final category = _category;

    if (category == null) {
      return Scaffold(
        backgroundColor: bgDeep,
        appBar: AppBar(
          title: const Text('Unknown Category'),
          backgroundColor: bgCard,
        ),
        body: const Center(
          child: Text(
            'Category not found.',
            style: TextStyle(color: textSecondary),
          ),
        ),
      );
    }

    final marketplaceSvc = ref.read(marketplaceServiceProvider);
    final allProviders = marketplaceSvc.getProviders(category);
    final providers = _sortedProviders(allProviders);

    return Scaffold(
      backgroundColor: bgDeep,
      appBar: AppBar(
        title: Text(category.label),
        backgroundColor: bgCard,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Filter chips ──────────────────────────────────────────
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isActive = _activeFilter == filter;
                return FilterChip(
                  label: Text(
                    filter,
                    style: TextStyle(
                      color: isActive ? bgDeep : textSecondary,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isActive,
                  selectedColor: accent,
                  backgroundColor: bgCard,
                  checkmarkColor: bgDeep,
                  side: BorderSide(
                    color: isActive
                        ? accent
                        : textSecondary.withValues(alpha: 0.3),
                  ),
                  onSelected: (_) => setState(() => _activeFilter = filter),
                );
              },
            ),
          ),

          // ── Provider list ─────────────────────────────────────────
          Expanded(
            child: providers.isEmpty
                ? Center(
                    child: Text(
                      'No providers found.',
                      style: TextStyle(
                        color: textSecondary.withValues(alpha: 0.6),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: providers.length,
                    itemBuilder: (context, index) {
                      final provider = providers[index];
                      return _ProviderCard(provider: provider)
                          .animate()
                          .fadeIn(
                            duration: 300.ms,
                            delay: (50 * index).ms,
                          )
                          .slideY(
                            begin: 0.1,
                            end: 0,
                            duration: 300.ms,
                            delay: (50 * index).ms,
                          );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// A single provider card in the list.
class _ProviderCard extends StatelessWidget {
  final MarketplaceProvider provider;

  const _ProviderCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: bgCard,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/marketplace/provider/${provider.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: name + badges
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        provider.name,
                        style: const TextStyle(
                          color: textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (provider.isVerified)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified,
                              color: Colors.blueAccent,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Verified',
                              style: TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (provider.hasDiscount)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          provider.discountLabel,
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 10),

                // Rating + reviews + price
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      provider.clampedRating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${provider.reviewCount})',
                      style: TextStyle(
                        color: textSecondary.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      provider.priceRange,
                      style: const TextStyle(
                        color: accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Address + distance
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: textSecondary.withValues(alpha: 0.6),
                      size: 15,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        provider.address,
                        style: TextStyle(
                          color: textSecondary.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${provider.distanceKm.toStringAsFixed(1)} km',
                      style: TextStyle(
                        color: textSecondary.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
