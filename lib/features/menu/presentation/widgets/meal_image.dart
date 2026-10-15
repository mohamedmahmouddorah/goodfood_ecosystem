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
    this.width,
    this.height,
    this.cacheWidth = 400,
  });

  final String url;
  final double? width;
  final double? height;
  final int cacheWidth;

  static const _placeholder = ColoredBox(color: MenuPalette.surface);
  static const _error = ColoredBox(
    color: MenuPalette.surface,
    child: Center(child: Icon(Icons.restaurant, color: MenuPalette.muted)),
  );

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _error;
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      memCacheWidth: cacheWidth,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, _) => _placeholder,
      errorWidget: (_, _, _) => _error,
    );
  }
}