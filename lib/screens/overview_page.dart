import 'package:flutter/material.dart';

import '../models/evaluation.dart';
import '../services/analytics.dart';
import '../services/data_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/panel.dart';

/// The dashboard's front page. Loads the fleet once, then renders.
class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  late Future<FleetData> _future;

  @override
  void initState() {
    super.initState();
    _future = DataService.loadAll();
  }

  void _reload() {
    setState(() => _future = DataService.loadAll());
  }

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
          return _ErrorPanel(
            message: 'Could not load the data. ${snapshot.error}',
            onRetry: _reload,
          );
        }

        final data = snapshot.data!;
        if (data.evaluations.isEmpty && data.farms.isEmpty) {
          return const _EmptyPanel();
        }

        return _Body(analytics: Analytics(data), onReload: _reload);
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.analytics, required this.onReload});

  final Analytics analytics;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final a = analytics;
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1080 ? 5 : (width >= 620 ? 3 : 2);

    final avg = a.averageScore;
    final change = a.averageScoreChange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- headline figures ----
        GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.72,
          children: [
            KpiTile(
              label: 'Farms registered',
              value: '${a.farmCount}',
              subline: '${a.farmsCovered} visited at least once',
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
              subline: _changeText(change),
              sublineColor: change == null
                  ? null
                  : (change >= 0 ? AppColors.greenLight : AppColors.orange),
            ),
            KpiTile(
              label: 'Head overseen',
              value: _thousands(a.totalHead),
              subline: 'latest visit per farm',
            ),
            KpiTile(
              label: 'Farms covered',
              value: '${a.farmsCovered}',
              suffix: ' / ${a.farmCount}',
              subline: '${a.overdueFarms().length} need a visit',
              sublineColor:
                  a.overdueFarms().isEmpty ? null : AppColors.amber,
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ---- the signature block ----
        Panel(
          title: 'Where the herd is weakest',
          note: 'Average score per section across '
              '${a.visitCount} submitted ${a.visitCount == 1 ? "visit" : "visits"}, '
              'worst first.',
          child: a.sectionRanking.isEmpty
              ? const Text(
                  'No section scores recorded yet.',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                )
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
        const SizedBox(height: 14),

        // ---- recent visits ----
        Panel(
          title: 'Recent visits',
          note: 'Newest first',
          child: _RecentList(visits: a.recentVisits()),
        ),
      ],
    );
  }

  static String _changeText(double? change) {
    if (change == null) return 'not enough history yet';
    final sign = change >= 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(1)} vs previous 30 days';
  }

  static String _thousands(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

/// One section in the weakness ranking: position, label, bar, score.
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
            : const Border(
                bottom: BorderSide(color: Color(0xFF2A2A2A)),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 26,
            child: Text(
              position.toString().padLeft(2, '0'),
              style: AppTheme.mono(size: 11, color: AppColors.muted),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        row.label,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      'n=${row.sampleSize}',
                      style: AppTheme.mono(size: 10, color: AppColors.muted),
                    ),
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
            child: Text(
              row.average.toStringAsFixed(1),
              textAlign: TextAlign.right,
              style: AppTheme.mono(size: 15, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentList extends StatelessWidget {
  const _RecentList({required this.visits});

  final List<Evaluation> visits;

  @override
  Widget build(BuildContext context) {
    if (visits.isEmpty) {
      return const Text(
        'No submitted visits yet.',
        style: TextStyle(fontSize: 13, color: AppColors.muted),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < visits.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              border: i == visits.length - 1
                  ? null
                  : const Border(
                      bottom: BorderSide(color: Color(0xFF2A2A2A))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visits[i].farmName,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${visits[i].county} · ${visits[i].eoName}',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.muted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _shortDate(visits[i].evaluationDate),
                  style: AppTheme.mono(size: 12, color: AppColors.text2),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 42,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.forTotalScore(visits[i].totalScore),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    '${visits[i].totalScore}',
                    style: AppTheme.mono(
                        size: 12.5,
                        weight: FontWeight.w600,
                        color: const Color(0xFF0D0D0D)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]}';
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Cannot load the dashboard',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(
                fontSize: 13, color: AppColors.text2, height: 1.6),
          ),
          const SizedBox(height: 18),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel();

  @override
  Widget build(BuildContext context) {
    return const Panel(
      title: 'Nothing to show yet',
      note: 'No farms or submitted visits have reached the database.',
      child: Text(
        'Once field officers submit visits from the mobile app, the figures '
        'appear here automatically.',
        style: TextStyle(fontSize: 13, color: AppColors.text2, height: 1.6),
      ),
    );
  }
}