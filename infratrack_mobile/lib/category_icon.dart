import 'package:flutter/material.dart';

import 'report_categories.dart';

String? categoryIconAsset(String? category) =>
    switch (normalizeReportCategory(category)) {
      'Roads' => 'assets/icons/roads.png',
      'Public Buildings' => 'assets/icons/public_buildings.png',
      'Drainage' => 'assets/icons/drainage.png',
      'Streetlights' => 'assets/icons/street_lights.png',
      'Electric Poles' => 'assets/icons/electric_poles.png',
      _ => null,
    };

class CategoryIcon extends StatelessWidget {
  const CategoryIcon({
    super.key,
    required this.category,
    required this.size,
    this.fallbackIcon,
    this.color,
  });

  final String? category;
  final double size;
  final IconData? fallbackIcon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final asset = categoryIconAsset(category);
    if (asset == null) {
      return Icon(
        fallbackIcon ?? Icons.category_outlined,
        size: size,
        color: color,
      );
    }

    return Image.asset(asset, width: size, height: size, fit: BoxFit.contain);
  }
}
