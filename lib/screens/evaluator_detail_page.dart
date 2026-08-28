import 'package:flutter/material.dart';

import '../models/evaluation.dart';
import '../services/analytics.dart';
import '../services/officer_stats.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/charts.dart';
import '../widgets/panel.dart';
import 'visit_detail_page.dart';

/// One officer: their output, their coverage, and how they score.
class EvaluatorDetailPage extends StatefulWidget {
  const EvaluatorDetailPage({
    super.key,
    required this.stats,
    required this.fleetAverage,
    required this.onBack,
  });

  final OfficerStats stats;

  /// The fleet-wide average score given, so this officer's own average has
  /// something to be read against. Null when there is nothing to compare.
  final double? fleetAverage;

  final VoidCallback onBack;

  @override
  State<EvaluatorDetailPage> createState() => _EvaluatorDetailPageState();
}

class _EvaluatorDetailPageState extends State<EvaluatorDetailPage> {
  Evaluation? _selected;

  @override
  Widget build(BuildContext context) {
    if (_selected != null) {
      return VisitDetailPage(
        visit: _selected!,
        onBack: () => setState(() => _selected = null),
        onDelete: null,
      );
    }

    final s = widget.stats;
    final u = s.user;
    final now = DateTime.now();
    final isWide = MediaQuery.sizeOf(context).width >= Layout.wideBreakpoint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('All evaluators'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.text2,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ---- identity ----
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.fill,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              alignment: Alignment.center,
              child: Text(u.initials,
                  style: AppTheme.mono(size: 17, color: AppColors.text2)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.displayName,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.4)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _Chip(
                        text: u.roleLabel,
                        color: u.isAdmin
                            ? AppColors.amber
                            : AppColors.greenLight,
                      ),
                      const SizedBox(width: 8),
                      if (!u.active)
                        const _Chip(
                            text: 'DEACTIVATED', color: AppColors.orange)
                      else if (s.isIdle(now))
                        const _Chip(text: 'IDLE', color: AppColors.muted)
                      else
                        const _Chip(
                            text: 'ACTIVE', color: AppColors.greenLight),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          u.username,
                          style: AppTheme.mono(
                              size: 12, color: AppColors.muted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (!s.hasVisits)
          Panel(
            title: 'No submitted visits',
            note: u.isAdmin
                ? 'This is an admin account. Admins do not normally do '
                    'fieldwork, so an empty record here is expected.'
                : 'This officer has an account but has not submitted any '
                    'evaluations yet.',
            child: Text(
              s.farmsRegistered > 0
                  ? 'They have registered ${s.farmsRegistered} '
                      '${s.farmsRegistered == 1 ? "farm" : "farms"}, so the '
                      'account is in use — the visits have not landed yet.'
                  : 'Nothing has been registered or submitted from this '
                      'account.',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.text2, height: 1.6),
            ),
          )
        else ...[
          _SummaryStrip(stats: s, now: now, fleetAverage: widget.fleetAverage),
          const SizedBox(height: 14),

          Panel(
            title: 'Visits per month',
            note: 'Last six months',
            child: VerticalBars(
              slices: s
                  .monthlyVisits(now)
                  .map((e) => Slice(e.key, e.value))
                  .toList(),
              barWidth: 62,
              emptyMessage: 'No visits in the last six months.',
            ),
          ),
          const SizedBox(height: 14),

          _TwoUp(
            isWide: isWide,
            left: Panel(
              title: 'How they score',
              note: 'Their average per section, worst first.',
              child: _SectionProfile(rows: s.sectionAverages),
            ),
            right: Panel(
              title: 'Farms covered',
              note: '${s.distinctFarms} '
                  '${s.distinctFarms == 1 ? "farm" : "farms"}, by visit count',
              child: HorizontalBars(
                slices: s.farmsCovered
                    .map((e) => Slice(e.key, e.value))
                    .toList(),
                labelWidth: isWide ? 140 : 110,
                valueSuffix: '',
              ),
            ),
          ),
          const SizedBox(height: 14),

          Panel(
            title: 'Recent visits',
            note: 'Newest first — open one for the full evaluation',
            child: Column(
              children: [
                for (var i = 0; i < s.recentVisits().length; i++)
                  _VisitRow(
                    visit: s.recentVisits()[i],
                    isLast: i == s.recentVisits().length - 1,
                    onTap: () => setState(
                        () => _selected = s.recentVisits()[i]),
                  ),
              ],
            ),
          ),
        ],

        if (SessionService.isAdmin) ...[
          const SizedBox(height: 14),
          Panel(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    size: 17, color: AppColors.muted),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Role changes and deactivation are handled in Settings, '
                    'where account administration lives.',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.muted,
                        height: 1.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.stats,
    required this.now,
    required this.fleetAverage,
  });

  final OfficerStats stats;
  final DateTime now;
  final double? fleetAverage;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1080 ? 5 : (width >= 620 ? 3 : 2);

    final avg = s.avgScoreGiven;
    final perMonth = s.avgVisitsPerMonth(now);

    // Difference from the fleet average, which is the number that says
    // whether this officer is calibrated with everyone else.
    final gap =
        (avg != null && fleetAverage != null) ? avg - fleetAverage! : null;

    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.72,
      children: [
        KpiTile(
          label: 'Total visits',
          value: '${s.visitCount}',
          subline: 'since ${Fmt.shortDate(s.firstVisit)}',
        ),
        KpiTile(
          label: 'Farms evaluated',
          value: '${s.distinctFarms}',
          subline: s.farmsRegistered > 0
              ? '${s.farmsRegistered} registered by them'
              : 'none registered by them',
        ),
        KpiTile(
          label: 'Avg score given',
          value: avg!.toStringAsFixed(1),
          suffix: ' / 35',
          subline: gap == null
              ? 'no fleet average to compare'
              : '${gap >= 0 ? '+' : ''}${gap.toStringAsFixed(1)} vs fleet',
          sublineColor: gap == null
              ? null
              : (gap.abs() > 3 ? AppColors.amber : AppColors.text2),
        ),
        KpiTile(
          label: 'Visits per month',
          value: perMonth!.toStringAsFixed(1),
          subline: 'from their first visit',
        ),
        KpiTile(
          label: 'Head covered',
          value: Fmt.thousands(s.headCovered),
          subline: 'latest visit per farm',
        ),
      ],
    );
  }
}

class _SectionProfile extends StatelessWidget {
  const _SectionProfile({required this.rows});

  final List<MapEntry<String, double>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Text('No section scores recorded.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted));
    }

    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 148,
                  child: Text(Sections.label(r.key),
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.text2),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (r.value / 5).clamp(0.0, 1.0),
                      minHeight: 7,
                      backgroundColor: const Color(0xFF2A2A2A),
                      valueColor: AlwaysStoppedAnimation(
                          AppColors.forSectionScore(r.value)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 30,
                  child: Text(r.value.toStringAsFixed(1),
                      textAlign: TextAlign.right,
                      style: AppTheme.mono(
                          size: 12.5,
                          color: AppColors.forSectionScore(r.value))),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _VisitRow extends StatelessWidget {
  const _VisitRow({
    required this.visit,
    required this.isLast,
    required this.onTap,
  });

  final Evaluation visit;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forTotalScore(visit.totalScore);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFF262626))),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 108,
              child: Text(Fmt.date(visit.evaluationDate),
                  style: AppTheme.mono(size: 12, color: AppColors.text2)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(visit.farmName,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                  if (visit.county.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(visit.county,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.muted)),
                  ],
                ],
              ),
            ),
            SizedBox(
              width: 74,
              child: Text('${Fmt.thousands(visit.totalHerd)} head',
                  textAlign: TextAlign.right,
                  style: AppTheme.mono(size: 11.5, color: AppColors.muted)),
            ),
            const SizedBox(width: 14),
            Container(
              width: 40,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${visit.totalScore}',
                  style: AppTheme.mono(
                      size: 12,
                      weight: FontWeight.w600,
                      color: const Color(0xFF0D0D0D))),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 17, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: AppTheme.mono(size: 10, color: color)),
    );
  }
}

class _TwoUp extends StatelessWidget {
  const _TwoUp({
    required this.isWide,
    required this.left,
    required this.right,
  });

  final bool isWide;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [left, const SizedBox(height: 14), right],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 14),
          Expanded(child: right),
        ],
      ),
    );
  }
}