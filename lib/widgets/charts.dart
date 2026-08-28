import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/analytics.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Hand-rolled charts rather than a charting package.
///
/// The dashboard needs three shapes, all simple, and every package would
/// bring its own theming to fight with the design tokens. Nothing here is
/// animated on purpose — a number that slides into place is harder to read
/// than one that is simply there.

/// Rows of label · bar · value. The right shape when labels are words
/// (names, counties) rather than dates.
class HorizontalBars extends StatelessWidget {
  const HorizontalBars({
    super.key,
    required this.slices,
    this.labelWidth = 130,
    this.color,
    this.valueSuffix = '',
    this.emptyMessage = 'Nothing in this period.',
  });

  final List<Slice> slices;
  final double labelWidth;

  /// One colour for every bar. When null, bars fade by magnitude — useful
  /// when the ranking itself is the message.
  final Color? color;

  final String valueSuffix;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return Text(emptyMessage,
          style: const TextStyle(fontSize: 12.5, color: AppColors.muted));
    }

    final max = slices.map((s) => s.value).reduce(math.max);
    final safeMax = max == 0 ? 1 : max;

    return Column(
      children: [
        for (final s in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: labelWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s.label,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.text2),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (s.sublabel != null)
                        Text(
                          s.sublabel!,
                          style: const TextStyle(
                              fontSize: 10.5, color: AppColors.muted),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 9,
                      child: Row(
                        children: [
                          Expanded(
                            flex: (s.value / safeMax * 1000).round().clamp(1, 1000),
                            child: Container(
                              color: color ??
                                  AppColors.greenLight.withValues(
                                      alpha: 0.35 +
                                          (s.value / safeMax) * 0.65),
                            ),
                          ),
                          Expanded(
                            flex: (1000 -
                                    (s.value / safeMax * 1000).round())
                                .clamp(0, 999),
                            child: Container(color: const Color(0xFF2A2A2A)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 62,
                  child: Text(
                    '${Fmt.thousands(s.value.round())}$valueSuffix',
                    textAlign: TextAlign.right,
                    style: AppTheme.mono(size: 12, color: AppColors.text2),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Vertical columns. Scrolls sideways rather than squeezing, because a
/// squashed bar chart with unreadable labels is worse than one you scroll.
class VerticalBars extends StatelessWidget {
  const VerticalBars({
    super.key,
    required this.slices,
    this.height = 190,
    this.barWidth = 44,
    this.color = AppColors.green,
    this.emptyMessage = 'Nothing in this period.',
  });

  final List<Slice> slices;
  final double height;
  final double barWidth;
  final Color color;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return Text(emptyMessage,
          style: const TextStyle(fontSize: 12.5, color: AppColors.muted));
    }

    final max = slices.map((s) => s.value).reduce(math.max);
    final safeMax = max == 0 ? 1 : max;
    const plotHeight = 120.0;

    return SizedBox(
      height: height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final s in slices)
              SizedBox(
                width: barWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      Fmt.thousands(s.value.round()),
                      style: AppTheme.mono(size: 10.5, color: AppColors.text2),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      width: barWidth - 12,
                      height: (s.value / safeMax * plotHeight)
                          .clamp(3, plotHeight)
                          .toDouble(),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                          bottom: Radius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    SizedBox(
                      height: 30,
                      child: Text(
                        s.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 9.5,
                            color: AppColors.muted,
                            height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A donut with the total in the middle and a legend beside it.
///
/// Donut rather than a full pie: the hole gives somewhere honest to put the
/// total, and comparing arc lengths is easier than comparing wedge areas.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.entries,
    this.centreLabel = '',
    this.emptyMessage = 'Nothing in this period.',
  });

  /// Label, value, colour — drawn in the order given.
  final List<(String, int, Color)> entries;

  final String centreLabel;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final total = entries.fold<int>(0, (a, e) => a + e.$2);

    if (total == 0) {
      return Text(emptyMessage,
          style: const TextStyle(fontSize: 12.5, color: AppColors.muted));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 132,
          height: 132,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(132, 132),
                painter: _DonutPainter(entries: entries, total: total),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$total',
                      style: AppTheme.mono(size: 24)
                          .copyWith(letterSpacing: -1, height: 1)),
                  if (centreLabel.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(centreLabel, style: AppTheme.eyebrow),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: e.$3,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(e.$1,
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.text2)),
                      ),
                      Text('${e.$2}',
                          style: AppTheme.mono(size: 12.5)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 42,
                        child: Text(
                          '${(e.$2 / total * 100).round()}%',
                          textAlign: TextAlign.right,
                          style: AppTheme.mono(
                              size: 11, color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.entries, required this.total});

  final List<(String, int, Color)> entries;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 22.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    // Start at twelve o'clock and run clockwise, which is how everyone
    // expects to read a proportion.
    var start = -math.pi / 2;

    for (final e in entries) {
      if (e.$2 == 0) continue;
      final sweep = (e.$2 / total) * math.pi * 2;

      canvas.drawArc(
        rect,
        start,
        // Small gap between segments so adjacent colours stay separable.
        sweep - 0.012,
        false,
        Paint()
          ..color = e.$3
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.total != total || old.entries != entries;
}