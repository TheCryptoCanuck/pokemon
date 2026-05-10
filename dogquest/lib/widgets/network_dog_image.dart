import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:dogquest/constants.dart';

class NetworkDogImage extends StatelessWidget {
  final String url;
  final double height;
  final double? width;
  final BoxFit fit;

  const NetworkDogImage({
    super.key,
    required this.url,
    required this.height,
    this.width,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: const {
        'User-Agent': 'Hound/1.0 (dog identification app)',
      },
      height: height,
      width: width ?? double.infinity,
      fit: fit,
      placeholder: (_, __) => Shimmer.fromColors(
        baseColor: bgCard,
        highlightColor: const Color(0xFF3A2F2A),
        child: Container(height: height, color: bgCard),
      ),
      errorWidget: (_, __, ___) => Container(
        height: height,
        color: bgCard,
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.white24, size: 48),
        ),
      ),
    );
  }
}
