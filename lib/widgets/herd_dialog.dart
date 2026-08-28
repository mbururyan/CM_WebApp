import 'package:flutter/material.dart';

import '../services/analytics.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// What the herd total is made of, by animal class.
///
/// Opened from the Overview's herd tile. Exists because a single "total
/// head" figure hides the thing a livestock manager actually asks: is this
/// a breeding herd, a growing herd, or a feedlot?
class HerdDialog extends StatelessWidget {
  const HerdDialog({
    super.key,
    required this.breakdown,
    required this.periodLabel,
  });

  final HerdBreakdown breakdown;

  /// The active date filter, spelled out — the total means nothing without
  /// knowing which window produced it.
  final String periodLabel;

  static Future<void> show(
    BuildContext context, {
    required HerdBreakdown breakdown,
    required String periodLabel,
  }) {
    return showDialog(
      context: context,
      builder: (_) =>
          HerdDialog(breakdown: breakdown, periodLabel: periodLabel),
    );
  }

  /// One colour per class, kept distinct from the score ramp so nobody
  /// reads a herd class as a rating.
  static const _classColors = <String, Color>{
    'Breeding cows': Color(0xFF7BC67E),
    'Growers / steers': Color(0xFF5C9EAD),
    'Calves': Color(0xFFE0A54D),
    'Bulls': Color(0xFFB08BBB),
  };

  @override
  Widget build(BuildContext context) {
    final b = breakdown;
    final rows = b.classes;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.amber.withValues(alpha: 0.45)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- header ----
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('HERD COMPOSITION',
                            style: AppTheme.eyebrow
                                .copyWith(color: AppColors.amber)),
                        const SizedBox(height: 8),
                        RichText(
                          text: TextSpan(
                            text: Fmt.thousands(b.total),
                            style: AppTheme.mono(size: 30)
                                .copyWith(letterSpacing: -1.2, height: 1),
                            children: [
                              TextSpan(
                                text: '  head',
                                style: AppTheme.mono(
                                        size: 13, color: AppColors.muted)
                                    .copyWith(letterSpacing: 0),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$periodLabel · ${b.farms} '
                          '${b.farms == 1 ? "farm" : "farms"} counted',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18),
                    color: AppColors.muted,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              if (b.total == 0)
                const Text(
                  'No farms were visited in this period, so there is nothing '
                  'to break down. Widen the date range.',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.text2, height: 1.6),
                )
              else ...[
                // ---- proportion bar ----
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: SizedBox(
                    height: 10,
                    child: Row(
                      children: [
                        for (final r in rows)
                          if (r.$2 > 0)
                            Expanded(
                              flex: r.$2,
                              child: Container(
                                color: _classColors[r.$1] ?? AppColors.muted,
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // ---- class rows ----
                for (var i = 0; i < rows.length; i++)
                  _ClassRow(
                    label: rows[i].$1,
                    count: rows[i].$2,
                    share: rows[i].$3,
                    color: _classColors[rows[i].$1] ?? AppColors.muted,
                    isLast: i == rows.length - 1,
                  ),

                const SizedBox(height: 18),
                const Divider(height: 1, color: Color(0xFF2A2A2A)),
                const SizedBox(height: 16),

                // ---- structure ratios ----
                Text('HERD STRUCTURE', style: AppTheme.eyebrow),
                const SizedBox(height: 10),
                _Ratio(
                  label: 'Cows per bull',
                  value: b.cowsPerBull == null
                      ? '—'
                      : b.cowsPerBull!.toStringAsFixed(1),
                  note: b.cowsPerBull == null
                      ? 'no bulls recorded'
                      : (b.cowsPerBull! > 30
                          ? 'high — few bulls for the cow herd'
                          : 'within the usual range'),
                  warn: b.cowsPerBull != null && b.cowsPerBull! > 30,
                ),
                const SizedBox(height: 8),
                _Ratio(
                  label: 'Calves per cow',
                  value: b.calvesPerCow == null
                      ? '—'
                      : b.calvesPerCow!.toStringAsFixed(2),
                  note: b.calvesPerCow == null
                      ? 'no breeding cows recorded'
                      : 'rough proxy for calving rate',
                ),
                const SizedBox(height: 8),
                _Ratio(
                  label: 'Average per farm',
                  value: Fmt.thousands(b.averagePerFarm.round()),
                  note: 'across ${b.farms} '
                      '${b.farms == 1 ? "farm" : "farms"}',
                ),

                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.fill,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Text(
                    'Counts come from each farm\u2019s most recent visit '
                    'inside the selected period. A farm visited twice is '
                    'counted once, and a farm not visited in the period is '
                    'not counted at all.',
                    style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.muted,
                        height: 1.55),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassRow extends StatelessWidget {
  const _ClassRow({
    required this.label,
    required this.count,
    required this.share,
    required this.color,
    required this.isLast,
  });

  final String label;
  final int count;
  final double share;
  final Color color;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 11),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: AppColors.text)),
          ),
          Text(Fmt.thousands(count), style: AppTheme.mono(size: 14)),
          SizedBox(
            width: 62,
            child: Text(
              '${share.toStringAsFixed(1)}%',
              textAlign: TextAlign.right,
              style: AppTheme.mono(size: 12, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _Ratio extends StatelessWidget {
  const _Ratio({
    required this.label,
    required this.value,
    required this.note,
    this.warn = false,
  });

  final String label;
  final String value;
  final String note;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 132,
          child: Text(label,
              style: const TextStyle(fontSize: 12.5, color: AppColors.text2)),
        ),
        Text(value,
            style: AppTheme.mono(
                size: 14, color: warn ? AppColors.amber : AppColors.text)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(note,
              style: TextStyle(
                  fontSize: 11.5,
                  color: warn ? AppColors.amber : AppColors.muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}