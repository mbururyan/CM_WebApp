import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/evaluation.dart';
import '../services/data_service.dart';
import '../services/export_service.dart';
import '../services/export_tables.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/panel.dart';

/// Everything known about one officer, assembled from their visits.
class OfficerStats {
  const OfficerStats({
    required this.user,
    required this.visits,
    required this.farmsRegistered,
  });

  final AppUser user;
  final List<Evaluation> visits;
  final int farmsRegistered;

  int get visitCount => visits.length;

  double? get avgScoreGiven {
    if (visits.isEmpty) return null;
    return visits.fold<int>(0, (a, v) => a + v.totalScore) / visits.length;
  }

  int get distinctFarms => visits.map((v) => v.farmId).toSet().length;

  DateTime? get lastActive {
    if (visits.isEmpty) return null;
    return visits
        .map((v) => v.evaluationDate)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// Idle when nothing has been submitted in 30 days. Deliberately not
  /// "inactive" — the account is fine, the fieldwork has just paused.
  bool isIdle(DateTime now) {
    final last = lastActive;
    if (last == null) return true;
    return now.difference(last).inDays > 30;
  }
}

/// The officer roster and how the fleet's scoring is spread across it.
class EvaluatorsPage extends StatefulWidget {
  const EvaluatorsPage({super.key});

  @override
  State<EvaluatorsPage> createState() => _EvaluatorsPageState();
}

class _EvaluatorsPageState extends State<EvaluatorsPage> {
  late Future<FleetData> _future;

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
        final stats = _build(data);

        // Evaluators only for the spread — an admin who scores nothing
        // would otherwise drag the calibration numbers around.
        final scorers = stats
            .where((s) => !s.user.isAdmin && s.avgScoreGiven != null)
            .toList();
        final averages = scorers.map((s) => s.avgScoreGiven!).toList()..sort();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Headline(stats: stats, averages: averages, now: now),
            const SizedBox(height: 14),
            _Table(stats: stats, now: now),
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
                      'spread, and only look closer at an officer sitting well '
                      'outside the pack.',
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

  List<OfficerStats> _build(FleetData data) {
    final byEo = <String, List<Evaluation>>{};
    for (final v in data.evaluations) {
      byEo.putIfAbsent(v.eoId, () => []).add(v);
    }

    final registered = <String, int>{};
    for (final f in data.farms) {
      registered[f.createdBy] = (registered[f.createdBy] ?? 0) + 1;
    }

    final rows = data.users
        .map((u) => OfficerStats(
              user: u,
              visits: byEo[u.uid] ?? const [],
              farmsRegistered: registered[u.uid] ?? 0,
            ))
        .toList();

    // Most active first; admins with no fieldwork settle at the bottom.
    rows.sort((a, b) => b.visitCount.compareTo(a.visitCount));
    return rows;
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
            : (counts[counts.length ~/ 2 - 1] + counts[counts.length ~/ 2]) /
                2);

    final spread =
        averages.length < 2 ? null : averages.last - averages.first;

    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 900 ? 3 : (width >= 560 ? 3 : 1);

    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: columns == 1 ? 4.2 : 1.72,
      children: [
        KpiTile(
          label: 'Active officers',
          value: '$active',
          suffix: ' / ${evaluators.length}',
          subline: idle == 0
              ? 'all submitted in the last 30 days'
              : '$idle idle over 30 days',
          sublineColor: idle == 0 ? null : AppColors.amber,
        ),
        KpiTile(
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
          label: 'Spread in avg score',
          value: spread == null ? '—' : spread.toStringAsFixed(1),
          subline: spread == null
              ? 'needs two scoring officers'
              : '${averages.first.toStringAsFixed(1)} lowest → '
                  '${averages.last.toStringAsFixed(1)} highest',
          // A wide spread means officers are not applying the rubric the
          // same way, which quietly undermines every other figure.
          sublineColor: spread != null && spread > 4 ? AppColors.amber : null,
        ),
      ],
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.stats, required this.now});

  final List<OfficerStats> stats;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.sizeOf(context).width > 900
                    ? MediaQuery.sizeOf(context).width - 300
                    : 780,
              ),
              child: Column(
                children: [
                  const _HeaderRow(),
                  for (final s in stats) _Row(stats: s, now: now),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Text(
                  '${stats.length} accounts · '
                  '${stats.where((s) => !s.user.isAdmin).length} evaluators, '
                  '${stats.where((s) => s.user.isAdmin).length} admin',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: stats.isEmpty
                      ? null
                      : () => ExportService.downloadCsv(
                            table: ExportTables.officerActivity(
                              stats.expand((s) => s.visits).toList(),
                            ),
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
          ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('OFFICER', style: AppTheme.eyebrow)),
          SizedBox(width: 92, child: Text('ROLE', style: AppTheme.eyebrow)),
          SizedBox(width: 60, child: Text('VISITS', style: AppTheme.eyebrow)),
          SizedBox(width: 60, child: Text('FARMS', style: AppTheme.eyebrow)),
          SizedBox(
              width: 96, child: Text('AVG GIVEN', style: AppTheme.eyebrow)),
          SizedBox(
              width: 110, child: Text('LAST ACTIVE', style: AppTheme.eyebrow)),
          SizedBox(width: 76, child: Text('STATUS', style: AppTheme.eyebrow)),
          if (SessionService.isAdmin) const SizedBox(width: 76),
        ],
      ),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({required this.stats, required this.now});

  final OfficerStats stats;
  final DateTime now;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.stats;
    final u = s.user;
    final avg = s.avgScoreGiven;
    final idle = s.isIdle(widget.now);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        color: _hover ? const Color(0xFF232323) : Colors.transparent,
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.fill,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    alignment: Alignment.center,
                    child: Text(u.initials,
                        style: AppTheme.mono(
                            size: 10.5, color: AppColors.text2)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u.displayName,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(u.username,
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.muted),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 92,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: u.isAdmin ? AppColors.amberDark : AppColors.fill,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(u.roleLabel,
                      style: AppTheme.mono(
                          size: 10,
                          color:
                              u.isAdmin ? AppColors.amber : AppColors.muted)),
                ),
              ),
            ),
            SizedBox(
              width: 60,
              child: Text('${s.visitCount}',
                  style: AppTheme.mono(size: 12.5, color: AppColors.text)),
            ),
            SizedBox(
              width: 60,
              child: Text('${s.farmsRegistered}',
                  style: AppTheme.mono(size: 12.5, color: AppColors.text2)),
            ),
            SizedBox(
              width: 96,
              child: avg == null
                  ? Text('—',
                      style:
                          AppTheme.mono(size: 12.5, color: AppColors.muted))
                  : Row(
                      children: [
                        Text(avg.toStringAsFixed(1),
                            style: AppTheme.mono(
                                size: 12.5,
                                color: AppColors.forTotalScore(avg.round()))),
                        const SizedBox(width: 6),
                        Text('/ 35',
                            style: AppTheme.mono(
                                size: 10, color: AppColors.muted)),
                      ],
                    ),
            ),
            SizedBox(
              width: 110,
              child: Text(Fmt.relative(s.lastActive, now: widget.now),
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.text2),
                  overflow: TextOverflow.ellipsis),
            ),
            SizedBox(
              width: 76,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: !u.active
                        ? const Color(0xFF3D211C)
                        : (idle ? AppColors.fill : AppColors.greenDark),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    !u.active ? 'OFF' : (idle ? 'IDLE' : 'ACTIVE'),
                    style: AppTheme.mono(
                      size: 10,
                      color: !u.active
                          ? AppColors.orange
                          : (idle ? AppColors.muted : AppColors.greenLight),
                    ),
                  ),
                ),
              ),
            ),
            if (SessionService.isAdmin)
              SizedBox(
                width: 76,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _IconAction(
                      icon: Icons.admin_panel_settings_outlined,
                      tooltip: u.isAdmin
                          ? 'Demote to evaluator'
                          : 'Promote to admin',
                      onTap: () => _soon(context),
                    ),
                    _IconAction(
                      icon: Icons.block,
                      tooltip: u.active ? 'Deactivate' : 'Reactivate',
                      danger: true,
                      onTap: () => _soon(context),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _soon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account changes are not built yet.'),
        backgroundColor: AppColors.fill,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, size: 16),
      color: danger ? AppColors.muted : AppColors.muted,
      hoverColor: danger ? const Color(0xFF2A1512) : AppColors.fill,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(),
      visualDensity: VisualDensity.compact,
    );
  }
}