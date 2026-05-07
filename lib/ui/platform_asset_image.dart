import 'package:flutter/material.dart';

/// A widget that renders an asset image using standard Image.asset on all platforms.
/// 
/// Works on Mobile, Desktop, and Web (with CanvasKit renderer).
class PlatformAssetImage extends StatelessWidget {
  final String assetPath;
  final String viewType;
  final double? width;
  final double? height;
  final BoxFit fit;

  const PlatformAssetImage({
    super.key,
    required this.assetPath,
    required this.viewType,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.error, color: Colors.red);
      },
    );

    // Apply 1.35x scale for Missiles as they appear too small
    if (viewType.contains('missile')) {
      return Transform.scale(
        scale: 1.35,
        child: image,
      );
    }

    return image;
  }
}
