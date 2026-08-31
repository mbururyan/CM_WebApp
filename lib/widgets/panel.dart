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
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
class KpiTile extends StatefulWidget {
  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    this.suffix,
    this.subline,
    this.sublineColor,
    this.accent,
    this.compact = false,
    this.onTap,
  });

  final String label;
  final String value;

  /// Rendered smaller after the value, e.g. the "/ 35" in "24.1 / 35".
  final String? suffix;

  final String? subline;
  final Color? sublineColor;

  /// Tints the border, background, label and chevron. Colour only.
  ///
  /// It used to change the tile's size as well, which was fine while one
  /// tile in the row was accented and became a problem the moment three
  /// were — see [compact].
  final Color? accent;

  /// Tighter padding and a smaller value, for a strip of tiles that is
  /// context for what sits below rather than the point of the page.
  ///
  /// Separate from [accent] so a row of tiles can carry different colours
  /// and still line up at the same size.
  final bool compact;

  /// Makes the tile clickable. A tile that does something must look like it
  /// does something, so this also adds a cursor, a hover lift and a corner
  /// chevron — an accent colour alone is decoration, not an affordance.
  final VoidCallback? onTap;

  @override
  State<KpiTile> createState() => _KpiTileState();
}

class _KpiTileState extends State<KpiTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final accented = widget.accent != null;
    final clickable = widget.onTap != null;
    final accent = widget.accent ?? AppColors.border;
    final tight = widget.compact;

    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: tight
          ? const EdgeInsets.fromLTRB(14, 11, 14, 11)
          : const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        // Blended rather than translucent, so tiles look identical whatever
        // sits behind them.
        color: accented
            ? Color.alphaBlend(
                accent.withValues(alpha: _hover && clickable ? 0.14 : 0.07),
                AppColors.surface)
            : AppColors.surface,
        border: Border.all(
          color: accented
              ? accent.withValues(alpha: _hover && clickable ? 0.9 : 0.5)
              : (clickable && _hover ? AppColors.muted : AppColors.border),
          width: accented && clickable ? 1.4 : 1,
        ),
        borderRadius: BorderRadius.circular(tight ? 11 : 14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.label.toUpperCase(),
                    style: AppTheme.eyebrow.copyWith(
                        color: clickable && accented
                            ? accent
                            : AppColors.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              // An unaccented tile has no accent colour to tint the chevron
              // with, and `border` is too dark to see — which would leave a
              // clickable tile looking dead. Fall back to the text greys.
              if (clickable)
                Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: accented
                      ? (_hover ? accent : accent.withValues(alpha: 0.6))
                      : (_hover ? AppColors.text2 : AppColors.muted),
                ),
            ],
          ),
          SizedBox(height: tight ? 5 : 7),
          RichText(
            text: TextSpan(
              text: widget.value,
              style: AppTheme.mono(
                      size: tight ? 19 : 26, weight: FontWeight.w500)
                  .copyWith(letterSpacing: -1, height: 1),
              children: [
                if (widget.suffix != null)
                  TextSpan(
                    text: widget.suffix,
                    style: AppTheme.mono(
                            size: tight ? 11 : 13, color: AppColors.text2)
                        .copyWith(letterSpacing: 0),
                  ),
              ],
            ),
          ),
          SizedBox(height: tight ? 4 : 7),
          // A space rather than nothing, so tiles in a row keep equal height
          // when only some have a subline.
          Text(
            widget.subline ?? ' ',
            style: TextStyle(
              fontSize: tight ? 10.5 : 11.5,
              color: widget.sublineColor ?? AppColors.text2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (!clickable) return tile;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(onTap: widget.onTap, child: tile),
    );
  }
}