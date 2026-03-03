import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../constants.dart';

class NetworkBirdImage extends StatelessWidget {
  final String url;
  final double height;
  final double? width;

  const NetworkBirdImage({super.key, required this.url, required this.height, this.width});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      height: height,
      width: width ?? double.infinity,
      fit: BoxFit.cover,
      placeholder: (_, __) => Shimmer.fromColors(
        baseColor: bgCard,
        highlightColor: const Color(0xFF2A3F2F),
        child: Container(height: height, color: bgCard),
      ),
      errorWidget: (_, __, ___) => Container(
        height: height,
        color: bgCard,
        child: const Center(child: Icon(Icons.broken_image, color: Colors.white24, size: 48)),
      ),
    );
  }
}
