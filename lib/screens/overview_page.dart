import 'package:flutter/material.dart';

import '../models/evaluation.dart';
import '../services/analytics.dart';
import '../services/data_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/charts.dart';
import '../widgets/herd_dialog.dart';
import '../widgets/panel.dart';

/// The dashboard's front page. Loads the fleet once, then re-slices it in
/// memory as the date filter changes — no refetch, so the filter is instant.
class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  late Future<FleetData> _future;

  /// Thirty days is the default: long enough to contain a working rhythm,
  /// short enough that "recent" still means recent.
  DateWindow _window = DateWindow.month;

  @override
  void initState() {
    super.initState();
    _future = DataService.loadAll();
  }

  void _reload() => setState(() => _future = DataService.loadAll());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FleetData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.greenLight),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Panel(
            title: 'Could not load the dashboard',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${snapshot.error}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.text2, height: 1.6)),
                const SizedBox(height: 18),
                OutlinedButton(
                    onPressed: _reload, child: const Text('Try again')),
              ],
            ),
          );
        }

        final data = snapshot.data!;
        if (data.farms.isEmpty && data.evaluations.isEmpty) {
          return const Panel(
            title: 'Nothing to show yet',
            note: 'No farms or submitted visits have reached the database.',
            child: Text(
              'Once field officers submit visits from the mobile app, the '
              'figures appear here automatically.',
              style: TextStyle(
                  fontSize: 13, color: AppColors.text2, height: 1.6),
            ),
          );
        }

        final a = Analytics(data, window: _window);
        return _Body(
          analytics: a,
          window: _window,
          onWindow: (w) => setState(() => _window = w),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.analytics,
    required this.window,
    required this.onWindow,
  });

  final Analytics analytics;
  final DateWindow window;
  final ValueChanged<DateWindow> onWindow;

  @override
  Widget build(BuildContext context) {
    final a = analytics;
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= Layout.wideBreakpoint;
    final columns = width >= 1080 ? 5 : (width >= 620 ? 3 : 2);

    final avg = a.averageScore;
    final change = a.averageScoreChange;
    final overdue = a.overdueFarms();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilterBar(window: window, onChanged: onWindow, visits: a.visitCount),
        const SizedBox(height: 16),

        // ---- headline figures ----
        GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.72,
          children: [
            // The only clickable tile on the page — gold outline and a
            // chevron so it reads as a door rather than a number.
            KpiTile(
              label: 'Total herd size',
              value: Fmt.thousands(a.totalHead),
              subline: '${a.farmsWithHerdData} farms · tap for breakdown',
              accent: AppColors.amber,
              onTap: () => HerdDialog.show(
                context,
                breakdown: a.herdBreakdown,
                periodLabel: window.label,
              ),
            ),
            KpiTile(
              label: 'Visits',
              value: '${a.visitCount}',
              subline: '${a.visitsThisWeek} this week',
            ),
            KpiTile(
              label: 'Average score',
              value: avg == null ? '—' : avg.toStringAsFixed(1),
              suffix: avg == null ? null : ' / 35',
              subline: _changeText(change, window),
              sublineColor: change == null
                  ? null
                  : (change >= 0 ? AppColors.greenLight : AppColors.orange),
            ),
            KpiTile(
              label: 'Farms registered',
              value: '${a.farmCount}',
              subline: '${a.farmsCovered} visited in this period',
            ),
            KpiTile(
              label: 'Need a visit',
              value: '${overdue.length}',
              subline: 'over ${a.overdueDays} days, or never',
              sublineColor: overdue.isEmpty ? null : AppColors.amber,
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ---- visits by evaluator ----
        Panel(
          title: 'Visits by evaluator',
          note: 'Submitted visits in this period.',
          child: HorizontalBars(
            slices: a.visitsByEvaluator,
            labelWidth: isWide ? 150 : 110,
            emptyMessage: 'No visits in this period.',
          ),
        ),
        const SizedBox(height: 14),

        // ---- herd by farm ----
        Panel(
          title: 'Herd size by farm',
          note: a.herdByFarm().length >= 15
              ? "Top 15 farms, each from its most recent visit in this period."
              : "Each farm's most recent visit in this period.",
          child: VerticalBars(
            slices: a.herdByFarm(),
            emptyMessage: 'No farms were visited in this period.',
          ),
        ),
        const SizedBox(height: 14),

        // ---- herd by county + rating mix ----
        _TwoUp(
          isWide: isWide,
          left: Panel(
            title: 'Herd size by county',
            note: 'Latest visit per farm, summed.',
            child: HorizontalBars(
              slices: a.herdByCounty,
              labelWidth: isWide ? 120 : 100,
              emptyMessage: 'No farms were visited in this period.',
            ),
          ),
          right: Panel(
            title: 'Visits by rating',
            note: 'Banded from the score, using the thresholds in Settings.',
            child: DonutChart(
              centreLabel: 'VISITS',
              entries: _ratingEntries(a.ratingMix),
              emptyMessage: 'No visits in this period.',
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ---- section ranking ----
        Panel(
          title: 'Where the herd is weakest',
          note: 'Average score per section across '
              '${a.visitCount} ${a.visitCount == 1 ? "visit" : "visits"}, '
              'worst first.',
          child: a.sectionRanking.isEmpty
              ? const Text('No section scores in this period.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted))
              : Column(
                  children: [
                    for (var i = 0; i < a.sectionRanking.length; i++)
                      _RankRow(
                        position: i + 1,
                        row: a.sectionRanking[i],
                        isLast: i == a.sectionRanking.length - 1,
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  /// Poor to excellent, on the score ramp, so the colours mean the same
  /// thing here as they do everywhere else in the app.
  static List<(String, int, Color)> _ratingEntries(Map<String, int> mix) => [
        ('Poor', mix['poor'] ?? 0, AppColors.scoreRamp[0]),
        ('Fair', mix['fair'] ?? 0, AppColors.scoreRamp[2]),
        ('Good', mix['good'] ?? 0, AppColors.scoreRamp[3]),
        ('Excellent', mix['excellent'] ?? 0, AppColors.scoreRamp[4]),
      ];

  static String _changeText(double? change, DateWindow w) {
    if (w == DateWindow.all) return 'across all visits';
    if (change == null) return 'no earlier period to compare';
    final sign = change >= 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(1)} vs previous ${w.days} days';
  }
}

/// The date filter. A menu behind an icon rather than five buttons in a
/// row — it is set once and then ignored, so it should not shout.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.window,
    required this.onChanged,
    required this.visits,
  });

  final DateWindow window;
  final ValueChanged<DateWindow> onChanged;
  final int visits;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PopupMenuButton<DateWindow>(
          tooltip: 'Change the date range',
          onSelected: onChanged,
          color: AppColors.surface,
          position: PopupMenuPosition.under,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.border),
          ),
          itemBuilder: (context) => [
            for (final w in DateWindow.values)
              PopupMenuItem(
                value: w,
                height: 40,
                child: Row(
                  children: [
                    Icon(
                      w == window ? Icons.check : null,
                      size: 15,
                      color: AppColors.greenLight,
                    ),
                    const SizedBox(width: 10),
                    Text(w.label, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.fill,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.filter_list,
                    size: 17, color: AppColors.text2),
                const SizedBox(width: 9),
                Text(window.label, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                const Icon(Icons.expand_more,
                    size: 16, color: AppColors.muted),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$visits ${visits == 1 ? "visit" : "visits"}',
          style: AppTheme.mono(size: 12, color: AppColors.muted),
        ),
      ],
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

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.position,
    required this.row,
    required this.isLast,
  });

  final int position;
  final SectionAverage row;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forSectionScore(row.average);

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
                      child: Text(row.label,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 9),
                    Text('n=${row.sampleSize}',
                        style:
                            AppTheme.mono(size: 10, color: AppColors.muted)),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (row.average / 5).clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: const Color(0xFF2A2A2A),
                    valueColor: AlwaysStoppedAnimation(color),
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
                style: AppTheme.mono(size: 15, color: color)),
          ),
        ],
      ),
    );
  }
}