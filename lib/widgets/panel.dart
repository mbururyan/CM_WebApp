import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// The standard bordered card. Every block on the dashboard sits in one of
/// these, so radius and border live in exactly one place.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.title,
    this.note,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final String? title;

  /// One line under the title explaining what the reader is looking at.
  final String? note;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Text(
              title!,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600),
            ),
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(
              note!,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
          if (title != null || note != null) const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// A single headline number with its label and a subline.
class KpiTile extends StatelessWidget {
  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    this.suffix,
    this.subline,
    this.sublineColor,
  });

  final String label;
  final String value;

  /// Rendered smaller after the value, e.g. the "/ 35" in "24.1 / 35".
  final String? suffix;

  final String? subline;
  final Color? sublineColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(), style: AppTheme.eyebrow),
          const SizedBox(height: 7),
          RichText(
            text: TextSpan(
              text: value,
              style: AppTheme.mono(size: 26, weight: FontWeight.w500)
                  .copyWith(letterSpacing: -1, height: 1),
              children: [
                if (suffix != null)
                  TextSpan(
                    text: suffix,
                    style: AppTheme.mono(size: 13, color: AppColors.text2)
                        .copyWith(letterSpacing: 0),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Text(
            subline ?? ' ',
            style: TextStyle(
              fontSize: 11.5,
              color: sublineColor ?? AppColors.text2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}