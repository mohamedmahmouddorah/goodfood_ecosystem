import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'menu_palette.dart';

/// One image widget for the whole feature.
/// `cacheWidth` decodes the picture at a small size, which is the biggest
/// memory saver in a grid of photos.
class MealImage extends StatelessWidget {
  const MealImage({
    super.key,
    required this.url,
    this.localPath,
    this.width,
    this.height,
    this.cacheWidth = 400,
    this.cacheHeight,
  });

  static const _maxCacheDimension = 2048;

  final String url;
  final String? localPath;
  final double? width;
  final double? height;
  final int cacheWidth;
  final int? cacheHeight;

  static const _placeholder = ColoredBox(color: MenuPalette.surface);
  static const _error = ColoredBox(
    color: MenuPalette.surface,
    child: Center(child: Icon(Icons.restaurant, color: MenuPalette.muted)),
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
        final targetWidth = _targetCacheDimension(
          constraints.maxWidth,
          cacheWidth,
          devicePixelRatio,
        );
        final targetHeight = _targetCacheDimension(
          constraints.maxHeight,
          cacheHeight ?? cacheWidth,
          devicePixelRatio,
        );
        final localPath = this.localPath;
        if (localPath != null && localPath.isNotEmpty) {
          return Image.file(
            File(localPath),
            width: width,
            height: height,
            fit: BoxFit.cover,
            cacheWidth: targetWidth,
            cacheHeight: targetHeight,
            errorBuilder: (_, _, _) => _error,
          );
        }
        if (url.isEmpty) return _error;
        return CachedNetworkImage(
          imageUrl: url,
          width: width,
          height: height,
          fit: BoxFit.cover,
          memCacheWidth: targetWidth,
          memCacheHeight: targetHeight,
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (_, _) => _placeholder,
          errorWidget: (_, _, _) => _error,
        );
      },
    );
  }

  int _targetCacheDimension(double logicalDimension, int fallback, double dpr) {
    if (!logicalDimension.isFinite || logicalDimension <= 0) return fallback;
    return (logicalDimension * dpr)
        .round()
        .clamp(1, _maxCacheDimension);
  }
}
