import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dogquest/services/dog_service.dart';
import 'package:dogquest/services/sighting_service.dart';

/// Builds the [MarkerLayer] for dog sighting pins on the Live Map.
class MapDogMarkers extends StatelessWidget {
  final List<Sighting> sightings;
  final DogService dogService;
  final ValueChanged<Sighting> onMarkerTapped;

  const MapDogMarkers({
    super.key,
    required this.sightings,
    required this.dogService,
    required this.onMarkerTapped,
  });

  @override
  Widget build(BuildContext context) {
    final markers = sightings.map((s) {
      final dog = dogService.lookupByCommonName(s.dogName);
      final color = dog != null ? dog.rarity.color : Colors.amber;
      return Marker(
        width: 36,
        height: 36,
        point: LatLng(s.latitude!, s.longitude!),
        child: GestureDetector(
          onTap: () => onMarkerTapped(s),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6),
              ],
            ),
            child: const Icon(Icons.pets, color: Colors.white, size: 18),
          ),
        ),
      );
    }).toList();

    return MarkerLayer(markers: markers);
  }
}
