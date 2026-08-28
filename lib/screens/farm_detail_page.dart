import 'package:flutter/material.dart';

import '../models/evaluation.dart';
import '../services/admin_service.dart';
import '../services/farm_stats.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/panel.dart';
import 'visit_detail_page.dart';

/// One farm: summary analytics, its section profile, and every visit.
class FarmDetailPage extends StatefulWidget {
  const FarmDetailPage({
    super.key,
    required this.stats,
    required this.onBack,
    required this.onChanged,
  });

  final FarmStats stats;
  final VoidCallback onBack;

  /// Called after a delete so the parent re-reads.
  final VoidCallback onChanged;

  @override
  State<FarmDetailPage> createState() => _FarmDetailPageState();
}

class _FarmDetailPageState extends State<FarmDetailPage> {
  Evaluation? _selected;

  Future<void> _deleteVisit(Evaluation v) async {
    final reason = await ConfirmDelete.show(
      context,
      title: 'Delete this visit?',
      subject: '${v.farmName} · ${Fmt.date(v.evaluationDate)} · '
          'by ${v.eoName} · ${v.totalScore}/35',
      consequence:
          'The visit disappears from every figure on this dashboard and from '
          'the exports. A full copy is kept in the deletions log.',
    );
    if (reason == null || !mounted) return;

    try {
      await AdminService.deleteEvaluation(
        evalId: v.id,
        summary: '${v.farmName} · ${Fmt.date(v.evaluationDate)} · '
            '${v.eoName} · ${v.totalScore}/35',
        reason: reason,
      );
      if (!mounted) return;
      _toast('Visit deleted and logged.');
      widget.onChanged();
    } on AdminFailure catch (e) {
      if (mounted) _toast(e.message, bad: true);
    } catch (e) {
      if (mounted) _toast('Delete failed: $e', bad: true);
    }
  }

  Future<void> _deleteFarm() async {
    final s = widget.stats;
    if (s.everVisited) {
      _toast(
        'This farm has ${s.visitCount} visits attached. Delete those first — '
        'otherwise they would point at a farm that no longer exists.',
        bad: true,
      );
      return;
    }

    final reason = await ConfirmDelete.show(
      context,
      title: 'Delete this farm?',
      subject: [s.farm.name, s.farm.locationArea, s.farm.county]
          .where((x) => x.isNotEmpty)
          .join(' · '),
      consequence:
          'The farm is removed from the register. It has no visits attached, '
          'so nothing else is affected. A full copy is kept in the deletions '
          'log.',
    );
    if (reason == null || !mounted) return;

    try {
      await AdminService.deleteFarm(
        farmId: s.farm.id,
        summary: '${s.farm.name} · ${s.farm.county}',
        reason: reason,
      );
      if (!mounted) return;
      _toast('Farm deleted and logged.');
      widget.onChanged();
    } on AdminFailure catch (e) {
      if (mounted) _toast(e.message, bad: true);
    } catch (e) {
      if (mounted) _toast('Delete failed: $e', bad: true);
    }
  }

  void _toast(String msg, {bool bad = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: bad ? const Color(0xFF2A1512) : AppColors.fill,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A visit opened from here returns here, not to the farms grid.
    if (_selected != null) {
      return VisitDetailPage(
        visit: _selected!,
        onBack: () => setState(() => _selected = null),
        onDelete:
            SessionService.isAdmin ? () => _deleteVisit(_selected!) : null,
      );
    }

    final s = widget.stats;
    final f = s.farm;
    final isWide = MediaQuery.sizeOf(context).width >= Layout.wideBreakpoint;
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('All farms'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.text2,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
        const SizedBox(height: 16),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.name,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.4)),
                  const SizedBox(height: 5),
                  Text(
                    [f.locationArea, f.subCounty, f.county, f.systemLabel]
                        .where((x) => x.isNotEmpty && x != '—')
                        .join(' · '),
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            if (SessionService.isAdmin)
              OutlinedButton.icon(
                onPressed: _deleteFarm,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.orange,
                  backgroundColor: Colors.transparent,
                  side: const BorderSide(color: Color(0xFF5A2B26)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),

        // ---- summary analytics ----
        if (s.everVisited) ...[
          _SummaryStrip(stats: s, now: now),
          const SizedBox(height: 14),
        ],

        _TwoUp(
          isWide: isWide,
          left: Panel(title: 'Farm details', child: _Details(stats: s)),
          right: Panel(
            title: 'Section profile',
            note: s.everVisited
                ? 'Averaged across all ${s.visitCount} '
                    '${s.visitCount == 1 ? "visit" : "visits"}, worst first.'
                : 'Nothing recorded yet.',
            child: s.everVisited
                ? _SectionProfile(stats: s)
                : const Text(
                    'Once an officer submits an evaluation, the section '
                    'breakdown appears here.',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.text2, height: 1.6),
                  ),
          ),
        ),
        const SizedBox(height: 14),

        if (s.visitCount >= 2) ...[
          Panel(
            title: 'Score history',
            note: '${s.visitCount} visits, oldest first',
            child: _History(visits: s.visits),
          ),
          const SizedBox(height: 14),
        ],

        Panel(
          title: 'Visits',
          note: s.everVisited
              ? 'Newest first — open one for the full evaluation'
              : 'Nothing recorded',
          child: !s.everVisited
              ? const Text('No submitted visits.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted))
              : Column(
                  children: [
                    for (var i = s.visits.length - 1; i >= 0; i--)
                      _VisitRow(
                        visit: s.visits[i],
                        previous: i > 0 ? s.visits[i - 1] : null,
                        isLast: i == 0,
                        onTap: () =>
                            setState(() => _selected = s.visits[i]),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Herd, average, latest, weakest, strongest — the five numbers that answer
/// "how is this farm doing" without opening a single visit.
class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.stats, required this.now});

  final FarmStats stats;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1080 ? 5 : (width >= 620 ? 3 : 2);
    final s = stats;

    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.72,
      children: [
        KpiTile(
          label: 'Herd size',
          value: Fmt.thousands(s.herdSize ?? 0),
          subline: 'at ${Fmt.shortDate(s.latest!.evaluationDate)}',
        ),
        KpiTile(
          label: 'Average score',
          value: s.averageScore!.toStringAsFixed(1),
          suffix: ' / 35',
          subline: 'across ${s.visitCount} '
              '${s.visitCount == 1 ? "visit" : "visits"}',
        ),
        KpiTile(
          label: 'Latest score',
          value: '${s.latestScore}',
          suffix: ' / 35',
          subline: s.trend == null
              ? Fmt.relative(s.latest!.evaluationDate, now: now)
              : '${s.trend! >= 0 ? '+' : ''}${s.trend} on previous visit',
          sublineColor: s.trend == null
              ? null
              : (s.trend! >= 0 ? AppColors.greenLight : AppColors.orange),
        ),
        KpiTile(
          label: 'Weakest',
          value: s.weakest!.value.toStringAsFixed(1),
          subline: Sections.label(s.weakest!.key),
          sublineColor: AppColors.orange,
        ),
        KpiTile(
          label: 'Strongest',
          value: s.strongest!.value.toStringAsFixed(1),
          subline: Sections.label(s.strongest!.key),
          sublineColor: AppColors.greenLight,
        ),
      ],
    );
  }
}

class _SectionProfile extends StatelessWidget {
  const _SectionProfile({required this.stats});

  final FarmStats stats;

  @override
  Widget build(BuildContext context) {
    final rows = stats.sectionAverages;

    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 150,
                  child: Text(
                    Sections.label(rows[i].key),
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.text2),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (rows[i].value / 5).clamp(0.0, 1.0),
                      minHeight: 7,
                      backgroundColor: const Color(0xFF2A2A2A),
                      valueColor: AlwaysStoppedAnimation(
                          AppColors.forSectionScore(rows[i].value)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 30,
                  child: Text(
                    rows[i].value.toStringAsFixed(1),
                    textAlign: TextAlign.right,
                    style: AppTheme.mono(
                        size: 12.5,
                        color: AppColors.forSectionScore(rows[i].value)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.stats});

  final FarmStats stats;

  @override
  Widget build(BuildContext context) {
    final f = stats.farm;
    final rows = <(String, String)>[
      ('Owner / manager', f.ownerManager),
      ('Contact', f.contactPhone),
      ('County', f.county),
      ('Sub-county', f.subCounty),
      ('Village', f.locationArea),
      ('Production system', f.systemLabel),
      ('Registered by', f.createdByName),
      ('Registered on', Fmt.date(f.createdAt)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 130,
                  child: Text(r.$1,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                ),
                Expanded(
                  child: Text(r.$2.isEmpty ? '—' : r.$2,
                      style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Total score per visit as columns. Not a line chart: visits are irregular
/// events, and a line implies values existed between them.
class _History extends StatelessWidget {
  const _History({required this.visits});

  final List<Evaluation> visits;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final v in visits)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${v.totalScore}',
                        style: AppTheme.mono(
                            size: 11,
                            color: AppColors.forTotalScore(v.totalScore))),
                    const SizedBox(height: 6),
                    // Scaled against 35 so bars are comparable across farms,
                    // not just within one.
                    Container(
                      height: (v.totalScore / 35 * 90).clamp(3, 90),
                      decoration: BoxDecoration(
                        color: AppColors.forTotalScore(v.totalScore),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                          bottom: Radius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(Fmt.shortDate(v.evaluationDate),
                        style:
                            AppTheme.mono(size: 9.5, color: AppColors.muted),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VisitRow extends StatelessWidget {
  const _VisitRow({
    required this.visit,
    required this.previous,
    required this.isLast,
    required this.onTap,
  });

  final Evaluation visit;
  final Evaluation? previous;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forTotalScore(visit.totalScore);

    // Only show a delta when the dates differ — two visits on the same day
    // produce an arbitrary sign.
    final showDelta = previous != null &&
        !_sameDay(previous!.evaluationDate, visit.evaluationDate);
    final delta = showDelta ? visit.totalScore - previous!.totalScore : null;

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
              child: Text(visit.eoName,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ),
            SizedBox(
              width: 74,
              child: Text('${Fmt.thousands(visit.totalHerd)} head',
                  textAlign: TextAlign.right,
                  style: AppTheme.mono(size: 11.5, color: AppColors.muted)),
            ),
            const SizedBox(width: 14),
            if (delta != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  '${delta >= 0 ? '+' : ''}$delta',
                  style: AppTheme.mono(
                    size: 12,
                    color:
                        delta >= 0 ? AppColors.greenLight : AppColors.orange,
                  ),
                ),
              ),
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

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
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