import 'package:flutter/material.dart';

import '../models/evaluation.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// One farm's scoring record inside the active window.
class FarmScore {
  const FarmScore({
    required this.farmName,
    required this.county,
    required this.average,
    required this.visits,
    required this.best,
    required this.worst,
  });

  final String farmName;
  final String county;
  final double average;

  /// Visits inside the window only. Shown so a 31.0 built from one visit
  /// is not read as a settled fact about the farm.
  final int visits;

  final int best;
  final int worst;
}

/// Which farms are pulling the fleet average up, and which are pulling it
/// down.
///
/// Opened from the Overview's average-score tile. A single fleet mean
/// answers "how are we doing" but hides "who"; this is the who.
class ScoreDialog extends StatelessWidget {
  const ScoreDialog({
    super.key,
    required this.rows,
    required this.fleetAverage,
    required this.visitCount,
    required this.periodLabel,
  });

  final List<FarmScore> rows;
  final double? fleetAverage;
  final int visitCount;

  /// The active date filter, spelled out — an average means nothing
  /// without knowing which window produced it.
  final String periodLabel;

  static const maxScore = 35;

  static Future<void> show(
    BuildContext context, {
    required List<Evaluation> visits,
    required double? fleetAverage,
    required String periodLabel,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ScoreDialog(
        rows: rank(visits),
        fleetAverage: fleetAverage,
        visitCount: visits.length,
        periodLabel: periodLabel,
      ),
    );
  }

  /// Group the window's visits by farm and average each one, best first.
  ///
  /// Averaged rather than taken from the latest visit: one bad day should
  /// not define a farm, and one good day should not flatter it. A farm
  /// visited twice in the window contributes both visits to its own mean
  /// but still occupies one row.
  static List<FarmScore> rank(List<Evaluation> visits) {
    final grouped = <String, List<Evaluation>>{};
    for (final v in visits) {
      if (v.farmId.isEmpty) continue;
      grouped.putIfAbsent(v.farmId, () => []).add(v);
    }

    final rows = <FarmScore>[];
    grouped.forEach((_, list) {
      var total = 0, best = list.first.totalScore, worst = list.first.totalScore;
      for (final v in list) {
        total += v.totalScore;
        if (v.totalScore > best) best = v.totalScore;
        if (v.totalScore < worst) worst = v.totalScore;
      }
      rows.add(FarmScore(
        farmName: list.first.farmName,
        county: list.first.county,
        average: total / list.length,
        visits: list.length,
        best: best,
        worst: worst,
      ));
    });

    rows.sort((a, b) {
      final byScore = b.average.compareTo(a.average);
      if (byScore != 0) return byScore;
      return a.farmName.toLowerCase().compareTo(b.farmName.toLowerCase());
    });
    return rows;
  }

  /// Banded through ConfigService, exactly as the donut and the visit list
  /// band their scores — so a farm shown as "good" here is good everywhere.
  static Color colourFor(double average) {
    final band = Evaluation.bandFor(average.round());
    if (band == 'poor') return AppColors.scoreRamp[0];
    if (band == 'fair') return AppColors.scoreRamp[2];
    if (band == 'good') return AppColors.scoreRamp[3];
    if (band == 'excellent') return AppColors.scoreRamp[4];
    return AppColors.muted;
  }

  @override
  Widget build(BuildContext context) {
    final avg = fleetAverage;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        // Capped against the viewport, not the content: twelve farms will
        // not fit a fixed-height card, and a dialog taller than the window
        // cannot be scrolled back to.
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
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
                        Text('AVERAGE SCORE', style: AppTheme.eyebrow),
                        const SizedBox(height: 8),
                        RichText(
                          text: TextSpan(
                            text: avg == null ? '—' : avg.toStringAsFixed(1),
                            style: AppTheme.mono(size: 30)
                                .copyWith(letterSpacing: -1.2, height: 1),
                            children: [
                              TextSpan(
                                text: '  / $maxScore',
                                style: AppTheme.mono(
                                        size: 13, color: AppColors.muted)
                                    .copyWith(letterSpacing: 0),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$periodLabel · $visitCount '
                          '${visitCount == 1 ? "visit" : "visits"} across '
                          '${rows.length} ${rows.length == 1 ? "farm" : "farms"}',
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

              if (rows.isEmpty)
                const Text(
                  'No visits were submitted in this period, so there is '
                  'nothing to rank. Widen the date range.',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.text2, height: 1.6),
                )
              else ...[
                const Divider(height: 1, color: Color(0xFF2A2A2A)),
                const SizedBox(height: 16),
                Text('BY FARM · BEST FIRST', style: AppTheme.eyebrow),
                const SizedBox(height: 12),

                // ---- ranked rows ----
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (var i = 0; i < rows.length; i++)
                          _ScoreRow(
                            position: i + 1,
                            row: rows[i],
                            isLast: i == rows.length - 1,
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.fill,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Text(
                    'Each farm is averaged across its own visits inside the '
                    'selected period. A farm visited twice appears once, '
                    'scored on both visits. A farm not visited in the period '
                    'does not appear at all.',
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

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.position,
    required this.row,
    required this.isLast,
  });

  final int position;
  final FarmScore row;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colour = ScoreDialog.colourFor(row.average);
    // Only worth showing a spread when there is more than one visit and the
    // two ends actually differ.
    final spread = row.visits > 1 && row.best != row.worst;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(position.toString().padLeft(2, '0'),
                style: AppTheme.mono(size: 11, color: AppColors.muted)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(row.farmName,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 9),
                    Text('n=${row.visits}',
                        style:
                            AppTheme.mono(size: 10, color: AppColors.muted)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  spread
                      ? '${row.county.isEmpty ? "—" : row.county} · '
                          '${row.worst}–${row.best}'
                      : (row.county.isEmpty ? '—' : row.county),
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (row.average / ScoreDialog.maxScore).clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: const Color(0xFF2A2A2A),
                    valueColor: AlwaysStoppedAnimation(colour),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 40,
            child: Text(row.average.toStringAsFixed(1),
                textAlign: TextAlign.right,
                style: AppTheme.mono(size: 15, color: colour)),
          ),
        ],
      ),
    );
  }
}