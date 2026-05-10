import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:dogquest/constants.dart';
import 'package:dogquest/models/dog.dart';

final _log = Logger('DogService');

class DogService {
  late final List<Dog> _dogs;
  late final Map<String, Dog> _index;

  /// Case-insensitive common name index (lowercase key -> Dog).
  late final Map<String, Dog> _commonIndex;

  /// Normalized common name index — handles word-order variants.
  /// Key is sorted lowercase words joined by space.
  late final Map<String, Dog> _normalizedCommonIndex;

  List<Dog> get all => _dogs;
  Map<String, Dog> get index => _index;

  /// Name aliases: maps ImageNet label names (lowercase) to the
  /// canonical common name used in our dogs.json database.
  static const _nameAliases = <String, String>{
    'japanese spaniel': 'Japanese Chin',
    'maltese dog': 'Maltese',
    'pekinese': 'Pekingese',
    'shih-tzu': 'Shih Tzu',
    'blenheim spaniel': 'Blenheim Spaniel',
    'toy terrier': 'Toy Terrier',
    'rhodesian ridgeback': 'Rhodesian Ridgeback',
    'afghan hound': 'Afghan Hound',
    'basset': 'Basset Hound',
    'bluetick': 'Bluetick Coonhound',
    'black-and-tan coonhound': 'Black and Tan Coonhound',
    'walker hound': 'Walker Hound',
    'english foxhound': 'English Foxhound',
    'redbone': 'Redbone Coonhound',
    'irish wolfhound': 'Irish Wolfhound',
    'italian greyhound': 'Italian Greyhound',
    'ibizan hound': 'Ibizan Hound',
    'norwegian elkhound': 'Norwegian Elkhound',
    'scottish deerhound': 'Scottish Deerhound',
    'staffordshire bullterrier': 'Staffordshire Bull Terrier',
    'american staffordshire terrier': 'American Staffordshire Terrier',
    'bedlington terrier': 'Bedlington Terrier',
    'border terrier': 'Border Terrier',
    'kerry blue terrier': 'Kerry Blue Terrier',
    'irish terrier': 'Irish Terrier',
    'norfolk terrier': 'Norfolk Terrier',
    'norwich terrier': 'Norwich Terrier',
    'yorkshire terrier': 'Yorkshire Terrier',
    'wire-haired fox terrier': 'Wire Fox Terrier',
    'lakeland terrier': 'Lakeland Terrier',
    'sealyham terrier': 'Sealyham Terrier',
    'airedale': 'Airedale Terrier',
    'cairn': 'Cairn Terrier',
    'australian terrier': 'Australian Terrier',
    'dandie dinmont': 'Dandie Dinmont Terrier',
    'boston bull': 'Boston Terrier',
    'miniature schnauzer': 'Miniature Schnauzer',
    'giant schnauzer': 'Giant Schnauzer',
    'standard schnauzer': 'Standard Schnauzer',
    'scotch terrier': 'Scottish Terrier',
    'tibetan terrier': 'Tibetan Terrier',
    'silky terrier': 'Silky Terrier',
    'soft-coated wheaten terrier': 'Soft-Coated Wheaten Terrier',
    'west highland white terrier': 'West Highland White Terrier',
    'lhasa': 'Lhasa Apso',
    'flat-coated retriever': 'Flat-Coated Retriever',
    'curly-coated retriever': 'Curly-Coated Retriever',
    'golden retriever': 'Golden Retriever',
    'labrador retriever': 'Labrador Retriever',
    'chesapeake bay retriever': 'Chesapeake Bay Retriever',
    'german short-haired pointer': 'German Shorthaired Pointer',
    'english setter': 'English Setter',
    'irish setter': 'Irish Setter',
    'gordon setter': 'Gordon Setter',
    'brittany spaniel': 'Brittany',
    'clumber': 'Clumber Spaniel',
    'english springer': 'English Springer Spaniel',
    'welsh springer spaniel': 'Welsh Springer Spaniel',
    'cocker spaniel': 'Cocker Spaniel',
    'sussex spaniel': 'Sussex Spaniel',
    'irish water spaniel': 'Irish Water Spaniel',
    'groenendael': 'Belgian Sheepdog',
    'malinois': 'Belgian Malinois',
    'kelpie': 'Australian Kelpie',
    'old english sheepdog': 'Old English Sheepdog',
    'shetland sheepdog': 'Shetland Sheepdog',
    'border collie': 'Border Collie',
    'bouvier des flandres': 'Bouvier des Flandres',
    'german shepherd': 'German Shepherd',
    'doberman': 'Doberman Pinscher',
    'miniature pinscher': 'Miniature Pinscher',
    'greater swiss mountain dog': 'Greater Swiss Mountain Dog',
    'bernese mountain dog': 'Bernese Mountain Dog',
    'appenzeller': 'Appenzeller Sennenhund',
    'entlebucher': 'Entlebucher Mountain Dog',
    'bull mastiff': 'Bullmastiff',
    'tibetan mastiff': 'Tibetan Mastiff',
    'french bulldog': 'French Bulldog',
    'great dane': 'Great Dane',
    'saint bernard': 'Saint Bernard',
    'eskimo dog':
        'Siberian Husky', // ImageNet "Eskimo dog" = sled dogs (huskies), NOT small American Eskimo
    'malamute': 'Alaskan Malamute',
    'siberian husky': 'Siberian Husky',
    'leonberg': 'Leonberger',
    'great pyrenees': 'Great Pyrenees',
    'chow': 'Chow Chow',
    'brabancon griffon': 'Brussels Griffon',
    'pembroke': 'Pembroke Welsh Corgi',
    'cardigan': 'Cardigan Welsh Corgi',
    'toy poodle': 'Toy Poodle',
    'miniature poodle': 'Miniature Poodle',
    'standard poodle': 'Standard Poodle',
    'mexican hairless': 'Xoloitzcuintli',
    // Direct labels that need explicit aliases to avoid fuzzy-match ambiguity
    'collie': 'Collie',
    'boxer': 'Boxer',
    'beagle': 'Beagle',
    'bloodhound': 'Bloodhound',
    'borzoi': 'Borzoi',
    'whippet': 'Whippet',
    'vizsla': 'Vizsla',
    'dalmatian': 'Dalmatian',
    'affenpinscher': 'Affenpinscher',
    'basenji': 'Basenji',
    'pug': 'Pug',
    'chihuahua': 'Chihuahua',
    'papillon': 'Papillon',
    'rottweiler': 'Rottweiler',
    'samoyed': 'Samoyed',
    'pomeranian': 'Pomeranian',
    'keeshond': 'Keeshond',
    'kuvasz': 'Kuvasz',
    'briard': 'Briard',
    'komondor': 'Komondor',
    'newfoundland': 'Newfoundland',
    'schipperke': 'Schipperke',
    'weimaraner': 'Weimaraner',
    'otterhound': 'Otterhound',
    // Dead ImageNet labels — map to closest app breed
    'dingo': 'Carolina Dog', // Carolina Dog = American Dingo
    'dhole': 'Canaan Dog', // Asian wild dog, visually closest to Canaan Dog
    'african hunting dog':
        'Pharaoh Hound', // African wild dog, prevent dead label
    // Supplemental breed aliases (case variants)
    // 'dalmatian' already mapped above
    'bulldog': 'Bulldog',
    'akita': 'Akita',
    'dachshund': 'Dachshund',
    'poodle': 'Poodle',
    'bull terrier': 'Bull Terrier',
  };

  Future<void> load() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/dogs.json');
      final List<dynamic> jsonList = json.decode(jsonStr) as List<dynamic>;
      _dogs = jsonList
          .map((e) => Dog.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
      _index = {for (final b in _dogs) b.name: b};

      // Build case-insensitive common name index.
      _commonIndex = {};
      _normalizedCommonIndex = {};
      for (final b in _dogs) {
        final lower = b.name.toLowerCase();
        _commonIndex.putIfAbsent(lower, () => b);
        _normalizedCommonIndex.putIfAbsent(
          _normalizeCommonName(b.name),
          () => b,
        );
      }

      // Register name aliases in the common name index
      for (final entry in _nameAliases.entries) {
        final target =
            _index[entry.value] ?? _commonIndex[entry.value.toLowerCase()];
        if (target != null) {
          _commonIndex.putIfAbsent(entry.key, () => target);
          _normalizedCommonIndex.putIfAbsent(
            _normalizeCommonName(entry.key),
            () => target,
          );
        }
      }

      _log.info('Loaded ${_dogs.length} dogs '
          '(${_commonIndex.length} common names incl. aliases)');
    } catch (e, st) {
      _log.severe('Failed to load dogs.json', e, st);
      rethrow;
    }
  }

  /// Normalize a common name for fuzzy matching:
  /// - lowercase
  /// - strip commas, hyphens, apostrophes
  /// - sort words alphabetically
  static String _normalizeCommonName(String name) {
    final cleaned = name
        .toLowerCase()
        .replaceAll(',', ' ')
        .replaceAll('-', ' ')
        .replaceAll("'", '')
        .replaceAll('  ', ' ')
        .trim();
    final words = cleaned.split(' ')..sort();
    return words.join(' ');
  }

  /// Primary common name lookup — exact match (case-sensitive).
  Dog? lookup(String name) => _index[name];

  /// Flexible common name lookup with progressive matching strategies:
  ///   1. Exact match (case-sensitive)
  ///   2. Case-insensitive match (includes aliases)
  ///   3. Normalized word-order match
  ///   4. Partial match (checks if query is a substring of any dog name)
  Dog? lookupByCommonName(String name) {
    if (name.isEmpty) return null;

    // 1. Exact match
    final exact = _index[name];
    if (exact != null) return exact;

    // 2. Case-insensitive (includes aliases registered in _commonIndex)
    final lower = name.toLowerCase();
    final byLower = _commonIndex[lower];
    if (byLower != null) return byLower;

    // 3. Normalized word-order match
    final normalized = _normalizeCommonName(name);
    final byNormalized = _normalizedCommonIndex[normalized];
    if (byNormalized != null) return byNormalized;

    // 4. Partial/substring match — find dogs whose name contains the query
    //    or the query contains the dog name. Use the longest matching name.
    Dog? bestPartial;
    int bestLen = 0;
    for (final entry in _commonIndex.entries) {
      if (entry.key.contains(lower) || lower.contains(entry.key)) {
        if (entry.key.length > bestLen) {
          bestLen = entry.key.length;
          bestPartial = entry.value;
        }
      }
    }
    if (bestPartial != null) return bestPartial;

    return null;
  }

  Dog unknownDog(String name) => Dog(
        name: name,
        scientificName: 'Species not yet in database',
        imageUrl: '',
        audioUrl: '',
        lore:
            'You found something we\'ve never seen before! This species isn\'t in our database yet. '
            'Your discovery has been logged and will help us grow Hound.',
        habitat: 'Unknown',
        conservationStatus: 'Unknown',
        rarity: Rarity.unknown,
        baseXp: 100,
      );

  /// Weighted random dog pick: common 60%, uncommon 25%, rare 12%, legendary 3%
  Dog weightedRandomDog(Random rng) {
    final r = rng.nextDouble();
    late Rarity rarity;
    if (r < 0.60) {
      rarity = Rarity.common;
    } else if (r < 0.85) {
      rarity = Rarity.uncommon;
    } else if (r < 0.97) {
      rarity = Rarity.rare;
    } else {
      rarity = Rarity.legendary;
    }
    final pool = _dogs.where((b) => b.rarity == rarity).toList();
    if (pool.isEmpty) {
      // Fallback to any dog if selected rarity pool is empty.
      return _dogs[rng.nextInt(_dogs.length)];
    }
    return pool[rng.nextInt(pool.length)];
  }

  List<Dog> filter({Rarity? rarity, String search = ''}) {
    return _dogs.where((b) {
      final matchRarity = rarity == null || b.rarity == rarity;
      final matchSearch = search.isEmpty ||
          b.name.toLowerCase().contains(search.toLowerCase()) ||
          b.scientificName.toLowerCase().contains(search.toLowerCase());
      return matchRarity && matchSearch;
    }).toList();
  }

  /// Search breeds by name for manual breed selection.
  /// Returns up to [limit] results matching the query.
  List<Dog> searchBreeds(String query, {int limit = 20}) {
    if (query.isEmpty) return _dogs.take(limit).toList();
    final lower = query.toLowerCase();
    return _dogs
        .where((d) => d.name.toLowerCase().contains(lower))
        .take(limit)
        .toList();
  }

  /// Poodle variant grouping: maps specific poodle variant names to the
  /// generic "Poodle" entry so it can be offered as an alternative.
  static const _poodleVariants = {
    'toy poodle',
    'miniature poodle',
    'standard poodle',
  };

  /// If the identified dog is a poodle variant, return the generic "Poodle"
  /// entry as an alternative (and vice versa). Returns null if not applicable.
  Dog? poodleAlternative(String identifiedName) {
    final lower = identifiedName.toLowerCase();
    if (_poodleVariants.contains(lower)) {
      // Identified a specific variant — offer generic Poodle
      return _index['Poodle'];
    }
    if (lower == 'poodle') {
      // Identified generic Poodle — offer no extra alternative
      // (the model already returns specific variants as alternatives)
      return null;
    }
    return null;
  }
}

final dogServiceProvider = Provider<DogService>((ref) {
  throw UnimplementedError(
    'dogServiceProvider must be overridden after loading',
  );
});
