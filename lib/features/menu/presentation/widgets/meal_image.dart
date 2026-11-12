import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'menu_palette.dart';

class MealImage extends StatelessWidget {
  const MealImage({
    super.key,
    required this.url,
    this.localPath,
    this.width,
    this.height,
    this.cacheWidth = 300,
    this.cacheHeight,
  });

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
    final localPathStr = localPath;
    if (localPathStr != null && localPathStr.isNotEmpty) {
      return Image.file(
        File(localPathStr),
        width: width,
        height: height,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight ?? cacheWidth,
        errorBuilder: (_, _, _) => _error,
      );
    }

    if (url.isEmpty) return _error;

    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      memCacheWidth: cacheWidth,
      memCacheHeight: cacheHeight ?? cacheWidth,
      fadeInDuration: const Duration(milliseconds: 100),
      placeholder: (_, _) => _placeholder,
      errorWidget: (_, _, _) => _error,
    );
  }
}