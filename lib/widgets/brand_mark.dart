import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The bull-skull mark on a green tile.
///
/// Points at `assets/icons/bull.png` — copy the same file the mobile app uses.
/// If the asset isn't there yet it falls back to an icon, so the app still runs.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 44,
    this.radius = 12,
    this.asset = 'assets/icons/bull.png',
    this.tint = true,
  });

  final double size;
  final double radius;

  /// Override if the file lands under a different name.
  final String asset;

  /// Recolours the mark to the light green. Set false if your PNG is already
  /// the colour you want, or if it's multi-coloured.
  final bool tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.greenDark,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Image.asset(
        asset,
        width: size * 0.58,
        height: size * 0.58,
        fit: BoxFit.contain,
        color: tint ? AppColors.greenLight : null,
        colorBlendMode: tint ? BlendMode.srcIn : BlendMode.srcOver,
        errorBuilder: (context, error, stack) => Icon(
          Icons.agriculture_outlined,
          size: size * 0.55,
          color: AppColors.greenLight,
        ),
      ),
    );
  }
}