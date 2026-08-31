import 'package:flutter/material.dart';

import '../models/evaluation.dart';
import '../services/analytics.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Which farms want attention, and why.
///
/// Opened from the Overview's need-a-visit tile. Two separate reasons live
/// here: nobody has been for a while, and the last person who went found
/// something bad. They are kept apart because they call for different
/// action — the first is a scheduling problem, the second is a farm
/// problem.
class OverdueDialog extends StatelessWidget {
  const OverdueDialog({
    super.key,
    required this.overdue,
    required this.poor,
    required this.overdueDays,
  });

  final List<OverdueFarm> overdue;

  /// Each farm's most recent visit ever, where that visit bands as poor and
  /// the farm is not already in [overdue]. No double-listing: a farm that
  /// is both overdue and poor appears once, under overdue, because getting
  /// someone there is the prior problem.
  final List<Evaluation> poor;

  final int overdueDays;

  static Color get _red => AppColors.scoreRamp[0];

  static Future<void> show(
    BuildContext context, {
    required List<OverdueFarm> overdue,
    required List<Evaluation> allVisits,
    required int overdueDays,
  }) {
    final listed = overdue.map((o) => o.farm.id).toSet();
    return showDialog(
      context: context,
      builder: (_) => OverdueDialog(
        overdue: overdue,
        poor: poorScorers(allVisits, exclude: listed),
        overdueDays: overdueDays,
      ),
    );
  }

  /// Farms whose latest visit ever bands as poor, worst first.
  ///
  /// Latest rather than averaged, unlike the score dialog: the question
  /// here is "what is the current state of this farm", and an old good
  /// visit should not soften a recent bad one.
  ///
  /// Computed against ALL visits, not the window — the same reasoning
  /// Analytics.overdueFarms uses. Whether a farm is in trouble is a fact
  /// about the farm, not about the date filter.
  static List<Evaluation> poorScorers(
    List<Evaluation> allVisits, {
    required Set<String> exclude,
  }) {
    final latest = <String, Evaluation>{};
    for (final v in allVisits) {
      if (v.farmId.isEmpty) continue;
      final held = latest[v.farmId];
      if (held == null || _isNewer(v, held)) latest[v.farmId] = v;
    }

    final rows = <Evaluation>[];
    latest.forEach((farmId, v) {
      if (exclude.contains(farmId)) return;
      if (Evaluation.bandFor(v.totalScore) == 'poor') rows.add(v);
    });

    rows.sort((a, b) => a.totalScore.compareTo(b.totalScore));
    return rows;
  }

  /// Same tie-break as Analytics: two visits on one day fall through to
  /// the server write time.
  static bool _isNewer(Evaluation candidate, Evaluation held) {
    final byDate = candidate.evaluationDate.compareTo(held.evaluationDate);
    if (byDate != 0) return byDate > 0;
    final a = candidate.createdAt, b = held.createdAt;
    if (a == null || b == null) return false;
    return a.isAfter(b);
  }

  @override
  Widget build(BuildContext context) {
    final never = overdue.where((o) => o.lastVisit == null).length;
    final nothing = overdue.isEmpty && poor.isEmpty;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _red.withValues(alpha: 0.45)),
      ),
      child: ConstrainedBox(
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
                        Text('NEEDS A VISIT',
                            style: AppTheme.eyebrow.copyWith(color: _red)),
                        const SizedBox(height: 8),
                        RichText(
                          text: TextSpan(
                            text: '${overdue.length}',
                            style: AppTheme.mono(size: 30)
                                .copyWith(letterSpacing: -1.2, height: 1),
                            children: [
                              TextSpan(
                                text: overdue.length == 1
                                    ? '  farm'
                                    : '  farms',
                                style: AppTheme.mono(
                                        size: 13, color: AppColors.muted)
                                    .copyWith(letterSpacing: 0),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          never == 0
                              ? 'not visited in over $overdueDays days'
                              : 'not visited in over $overdueDays days · '
                                  '$never never visited',
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

              if (nothing)
                Text(
                  'Every farm on the register has been visited within '
                  '$overdueDays days, and none of them scored poorly on '
                  'that visit. Nothing needs chasing.',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.text2, height: 1.6),
                )
              else ...[
                const Divider(height: 1, color: Color(0xFF2A2A2A)),
                const SizedBox(height: 16),

                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (overdue.isNotEmpty) ...[
                          Text('OVERDUE · LONGEST FIRST',
                              style: AppTheme.eyebrow),
                          const SizedBox(height: 12),
                          for (var i = 0; i < overdue.length; i++)
                            _OverdueRow(
                              row: overdue[i],
                              isLast: i == overdue.length - 1,
                            ),
                        ],
                        if (overdue.isNotEmpty && poor.isNotEmpty)
                          const SizedBox(height: 22),
                        if (poor.isNotEmpty) ...[
                          Text('SCORING POORLY · WORST FIRST',
                              style: AppTheme.eyebrow.copyWith(color: _red)),
                          const SizedBox(height: 4),
                          const Text(
                            'Visited recently enough, but the last visit '
                            'came back poor.',
                            style: TextStyle(
                                fontSize: 11.5, color: AppColors.muted),
                          ),
                          const SizedBox(height: 12),
                          for (var i = 0; i < poor.length; i++)
                            _PoorRow(
                              visit: poor[i],
                              isLast: i == poor.length - 1,
                            ),
                        ],
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
                  child: Text(
                    'Both lists ignore the date filter — whether a farm is '
                    'overdue is a fact about the calendar, not about the '
                    'window you are looking through. The $overdueDays day '
                    'threshold and the poor band both come from Settings.',
                    style: const TextStyle(
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

class _OverdueRow extends StatelessWidget {
  const _OverdueRow({required this.row, required this.isLast});

  final OverdueFarm row;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final farm = row.farm;
    final place = [farm.subCounty, farm.county]
        .where((s) => s.trim().isNotEmpty)
        .join(', ');
    final never = row.lastVisit == null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(farm.name,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  place.isEmpty ? '—' : place,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                never ? 'Never' : '${row.daysSince} days',
                style: AppTheme.mono(
                    size: 13,
                    color: never
                        ? OverdueDialog._red
                        : AppColors.amber),
              ),
              const SizedBox(height: 4),
              Text(
                never ? 'no visit on record' : Fmt.date(row.lastVisit),
                style: AppTheme.mono(size: 10.5, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PoorRow extends StatelessWidget {
  const _PoorRow({required this.visit, required this.isLast});

  final Evaluation visit;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(visit.farmName,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  visit.county.isEmpty ? '—' : visit.county,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              RichText(
                text: TextSpan(
                  text: '${visit.totalScore}',
                  style: AppTheme.mono(size: 13, color: OverdueDialog._red),
                  children: [
                    TextSpan(
                      text: ' / 35',
                      style:
                          AppTheme.mono(size: 10.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(Fmt.relative(visit.evaluationDate),
                  style: AppTheme.mono(size: 10.5, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}