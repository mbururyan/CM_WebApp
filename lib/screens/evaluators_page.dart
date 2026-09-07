import 'package:flutter/material.dart';

import '../services/data_service.dart';
import '../services/export_service.dart';
import '../services/export_tables.dart';
import '../services/officer_stats.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/filter_bar.dart';
import '../widgets/panel.dart';
import 'evaluator_detail_page.dart';

/// The roster: every registered account, and how the fleet's scoring is
/// spread across the people doing the work.
class EvaluatorsPage extends StatefulWidget {
  const EvaluatorsPage({super.key});

  @override
  State<EvaluatorsPage> createState() => _EvaluatorsPageState();
}

class _EvaluatorsPageState extends State<EvaluatorsPage> {
  late Future<FleetData> _future;
  String? _selectedUid;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _future = DataService.loadAll(withUsers: true);
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
          return Panel(
            title: 'Could not load accounts',
            child: Text('${snapshot.error}',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.text2, height: 1.6)),
          );
        }

        final data = snapshot.data!;
        final now = DateTime.now();
        final stats = OfficerStats.buildAll(data);

        // Evaluators only — an admin who scores nothing would drag the
        // calibration figures around without meaning anything.
        final scorers = stats
            .where((s) => !s.user.isAdmin && s.avgScoreGiven != null)
            .toList();
        final averages = scorers.map((s) => s.avgScoreGiven!).toList()..sort();
        final fleetAverage = averages.isEmpty
            ? null
            : averages.reduce((a, b) => a + b) / averages.length;

        if (_selectedUid != null) {
          final match =
              stats.where((s) => s.user.uid == _selectedUid).toList();
          if (match.isNotEmpty) {
            return EvaluatorDetailPage(
              stats: match.first,
              fleetAverage: fleetAverage,
              onBack: () => setState(() => _selectedUid = null),
            );
          }
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => setState(() => _selectedUid = null));
        }

        // The headline and the fleet average are computed from EVERY
        // account on purpose. They are calibration figures, and a
        // calibration figure that moves when you type in a search box is
        // not a calibration figure. Only the grid narrows.
        final query = _search.trim().toLowerCase();
        final visible = query.isEmpty
            ? stats
            : stats
                .where((s) =>
                    s.user.displayName.toLowerCase().contains(query) ||
                    s.user.roleLabel.toLowerCase().contains(query))
                .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Headline(stats: stats, averages: averages, now: now),
            const SizedBox(height: 16),
            FilterBar(
              children: [
                FilterSearch(
                  hint: 'Search by name or role',
                  value: _search,
                  onChanged: (v) => setState(() => _search = v),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (visible.isEmpty)
              Panel(
                title: 'No matching accounts',
                child: Text(
                  'Nothing on the roster matches \u201C$_search\u201D.',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.text2, height: 1.6),
                ),
              )
            else
              _Grid(
                stats: visible,
                now: now,
                fleetAverage: fleetAverage,
                onOpen: (s) => setState(() => _selectedUid = s.user.uid),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  query.isEmpty
                      ? '${stats.length} accounts \u00B7 '
                          '${stats.where((s) => !s.user.isAdmin).length} '
                          'evaluators, '
                          '${stats.where((s) => s.user.isAdmin).length} admin'
                      : '${visible.length} of ${stats.length} accounts match',
                  style: AppTheme.mono(size: 12, color: AppColors.muted),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: data.evaluations.isEmpty
                      ? null
                      : () => ExportService.downloadCsv(
                            table: ExportTables.officerActivity(
                                data.evaluations),
                            filename:
                                ExportService.stamped('cm-officer-activity'),
                          ),
                  icon: const Icon(Icons.download_outlined, size: 15),
                  label: const Text('Export'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
              ],
            ),
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
                      'Average score given is a calibration signal, not a '
                      'performance measure. A high average may mean lenient '
                      'scoring rather than better farms — read it against the '
                      'spread, and only look closer at an officer sitting '
                      'well outside the pack.',
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
        );
      },
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({
    required this.stats,
    required this.averages,
    required this.now,
  });

  final List<OfficerStats> stats;
  final List<double> averages;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final evaluators = stats.where((s) => !s.user.isAdmin).toList();
    final active = evaluators.where((s) => !s.isIdle(now)).length;
    final idle = evaluators.length - active;

    final counts = evaluators.map((s) => s.visitCount).toList()..sort();
    final median = counts.isEmpty
        ? null
        : (counts.length.isOdd
            ? counts[counts.length ~/ 2].toDouble()
            : (counts[counts.length ~/ 2 - 1] +
                    counts[counts.length ~/ 2]) /
                2);

    final spread = averages.length < 2 ? null : averages.last - averages.first;
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 620 ? 3 : 1;

    // Wider aspect ratio = shorter tiles. These are context for the roster
    // below, not the main event, and at 1.72 they dominated the page.
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: columns == 1 ? 6.0 : 3.1,
      children: [
        KpiTile(
          accent: AppColors.greenLight,
          label: 'Active officers',
          value: '$active',
          suffix: ' / ${evaluators.length}',
          subline: idle == 0
              ? 'all submitted in the last 30 days'
              : '$idle idle over 30 days',
          sublineColor: idle == 0 ? null : AppColors.amber,
        ),
        KpiTile(
          accent: AppColors.greenLight,
          label: 'Visits per officer',
          value: evaluators.isEmpty
              ? '—'
              : (evaluators.fold<int>(0, (a, s) => a + s.visitCount) /
                      evaluators.length)
                  .toStringAsFixed(1),
          subline: median == null
              ? 'no visits yet'
              : 'median ${median.toStringAsFixed(median == median.roundToDouble() ? 0 : 1)}',
        ),
        KpiTile(
          accent: AppColors.greenLight,
          label: 'Spread in avg score',
          value: spread == null ? '—' : spread.toStringAsFixed(1),
          subline: spread == null
              ? 'needs two scoring officers'
              : '${averages.first.toStringAsFixed(1)} → '
                  '${averages.last.toStringAsFixed(1)}',
          // A wide spread means officers are not applying the rubric the
          // same way, which quietly undermines every other figure.
          sublineColor: spread != null && spread > 4 ? AppColors.amber : null,
        ),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.stats,
    required this.now,
    required this.fleetAverage,
    required this.onOpen,
  });

  final List<OfficerStats> stats;
  final DateTime now;
  final double? fleetAverage;
  final ValueChanged<OfficerStats> onOpen;

  @override
  Widget build(BuildContext context) {
    // One officer per row. A roster is read down a column of names, not
    // scanned across a grid — and the row has space for every metric
    // without truncating.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < stats.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == stats.length - 1 ? 0 : 10),
            child: _OfficerCard(
              stats: stats[i],
              now: now,
              fleetAverage: fleetAverage,
              onTap: () => onOpen(stats[i]),
            ),
          ),
      ],
    );
  }
}

class _OfficerCard extends StatefulWidget {
  const _OfficerCard({
    required this.stats,
    required this.now,
    required this.fleetAverage,
    required this.onTap,
  });

  final OfficerStats stats;
  final DateTime now;
  final double? fleetAverage;
  final VoidCallback onTap;

  @override
  State<_OfficerCard> createState() => _OfficerCardState();
}

class _OfficerCardState extends State<_OfficerCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.stats;
    final u = s.user;
    final avg = s.avgScoreGiven;
    final perMonth = s.avgVisitsPerMonth(widget.now);
    final idle = s.isIdle(widget.now);
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _hover ? const Color(0xFF232323) : AppColors.surface,
            border: Border.all(
                color: _hover ? const Color(0xFF4A4A4A) : AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // ---- identity ----
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.fill,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                alignment: Alignment.center,
                child: Text(u.initials,
                    style: AppTheme.mono(size: 13, color: AppColors.text2)),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: isWide ? 190 : 130,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(u.displayName,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(u.username,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: u.isAdmin ? AppColors.amberDark : AppColors.fill,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(u.roleLabel,
                    style: AppTheme.mono(
                        size: 9.5,
                        color:
                            u.isAdmin ? AppColors.amber : AppColors.muted)),
              ),

              const Spacer(),

              // ---- metrics ----
              if (!s.hasVisits)
                Text(
                  s.farmsRegistered > 0
                      ? 'No visits · ${s.farmsRegistered} farms registered'
                      : 'No visits submitted',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.muted),
                )
              else if (isWide) ...[
                _Metric(label: 'Visits', value: '${s.visitCount}'),
                _Metric(label: 'Farms', value: '${s.distinctFarms}'),
                _Metric(
                  label: 'Avg given',
                  value: avg!.toStringAsFixed(1),
                  color: AppColors.forTotalScore(avg.round()),
                ),
                _Metric(
                    label: 'Per month', value: perMonth!.toStringAsFixed(1)),
                _Metric(
                    label: 'Head', value: Fmt.thousands(s.headCovered)),
              ] else
                _Metric(
                  label: 'Visits',
                  value: '${s.visitCount}',
                ),

              const SizedBox(width: 16),

              // ---- status ----
              SizedBox(
                width: isWide ? 130 : 70,
                child: Row(
                  children: [
                    Icon(
                      !u.active
                          ? Icons.block
                          : (idle ? Icons.schedule : Icons.circle),
                      size: !u.active ? 13 : (idle ? 13 : 8),
                      color: !u.active
                          ? AppColors.orange
                          : (idle
                              ? AppColors.muted
                              : AppColors.greenLight),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        !u.active
                            ? 'Off'
                            : (isWide
                                ? Fmt.relative(s.lastActive,
                                    now: widget.now)
                                : (idle ? 'Idle' : 'Active')),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: !u.active
                              ? AppColors.orange
                              : AppColors.muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 17,
                  color: _hover ? AppColors.text2 : AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // Fixed width, not Expanded: this now sits in a Row that already has a
    // Spacer, and two competing flex rules would fight.
    return SizedBox(
      width: 86,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: AppTheme.mono(size: 15, color: color ?? AppColors.text)),
          const SizedBox(height: 2),
          Text(label.toUpperCase(), style: AppTheme.eyebrow),
        ],
      ),
    );
  }
}