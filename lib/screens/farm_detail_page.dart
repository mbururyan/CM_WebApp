import 'package:flutter/material.dart';

import '../models/evaluation.dart';
import '../models/farm.dart';
import '../services/admin_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/panel.dart';
import 'visit_detail_page.dart';

/// One farm: its details, its score history, and every visit made to it.
class FarmDetailPage extends StatefulWidget {
  const FarmDetailPage({
    super.key,
    required this.farm,
    required this.visits,
    required this.onBack,
    required this.onChanged,
  });

  final Farm farm;

  /// Every submitted visit to this farm. Order doesn't matter — sorted here.
  final List<Evaluation> visits;

  final VoidCallback onBack;

  /// Called after a delete so the parent re-reads and this page pops.
  final VoidCallback onChanged;

  @override
  State<FarmDetailPage> createState() => _FarmDetailPageState();
}

class _FarmDetailPageState extends State<FarmDetailPage> {
  Evaluation? _selected;

  List<Evaluation> get _ordered {
    final list = [...widget.visits]..sort((a, b) {
        final byDate = a.evaluationDate.compareTo(b.evaluationDate);
        if (byDate != 0) return byDate;
        final x = a.createdAt, y = b.createdAt;
        if (x == null || y == null) return 0;
        return x.compareTo(y);
      });
    return list;
  }

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

  Future<void> _deleteFarm(Farm f, bool hasVisits) async {
    // Caught here as well as in the service, so the user gets the reason
    // before typing anything rather than after.
    if (hasVisits) {
      _toast(
        'This farm has visits attached. Delete those first — otherwise they '
        'would be left pointing at a farm that no longer exists.',
        bad: true,
      );
      return;
    }

    final reason = await ConfirmDelete.show(
      context,
      title: 'Delete this farm?',
      subject: [f.name, f.locationArea, f.county]
          .where((s) => s.isNotEmpty)
          .join(' · '),
      consequence:
          'The farm is removed from the register. It has no visits attached, '
          'so nothing else is affected. A full copy is kept in the deletions '
          'log.',
    );
    if (reason == null || !mounted) return;

    try {
      await AdminService.deleteFarm(
        farmId: f.id,
        summary: '${f.name} · ${f.county}',
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
    // A visit opened from here returns here, not to the farms table.
    if (_selected != null) {
      return VisitDetailPage(
        visit: _selected!,
        onBack: () => setState(() => _selected = null),
        onDelete: SessionService.isAdmin
            ? () => _deleteVisit(_selected!)
            : null,
      );
    }

    final f = widget.farm;
    final visits = _ordered;
    final latest = visits.isEmpty ? null : visits.last;
    final isWide = MediaQuery.sizeOf(context).width >= Layout.wideBreakpoint;

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

        Text(
          f.name,
          style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.4),
        ),
        const SizedBox(height: 5),
        Text(
          [f.locationArea, f.subCounty, f.county, f.systemLabel]
              .where((s) => s.isNotEmpty && s != '—')
              .join(' · '),
          style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        if (SessionService.isAdmin) ...[
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _deleteFarm(f, visits.isNotEmpty),
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Delete farm'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.orange,
                backgroundColor: Colors.transparent,
                side: const BorderSide(color: Color(0xFF5A2B26)),
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),

        // ---- details + latest snapshot ----
        _TwoUp(
          isWide: isWide,
          left: Panel(
            title: 'Farm details',
            child: _Details(farm: f),
          ),
          right: Panel(
            title: latest == null ? 'No visits yet' : 'As of the last visit',
            note: latest == null
                ? 'This farm has been registered but never evaluated.'
                : Fmt.date(latest.evaluationDate),
            child: latest == null
                ? const Text(
                    'Once an officer submits an evaluation, its score and '
                    'herd counts appear here.',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.text2, height: 1.6),
                  )
                : _LatestSnapshot(latest: latest),
          ),
        ),
        const SizedBox(height: 14),

        // ---- score history ----
        if (visits.length >= 2) ...[
          Panel(
            title: 'Score history',
            note: '${visits.length} visits, oldest first',
            child: _History(visits: visits),
          ),
          const SizedBox(height: 14),
        ],

        // ---- visit list ----
        Panel(
          title: 'Visits',
          note: visits.isEmpty
              ? 'Nothing recorded'
              : 'Newest first — open one for the full evaluation',
          child: visits.isEmpty
              ? const Text(
                  'No submitted visits.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                )
              : Column(
                  children: [
                    for (var i = visits.length - 1; i >= 0; i--)
                      _VisitRow(
                        visit: visits[i],
                        previous: i > 0 ? visits[i - 1] : null,
                        isLast: i == 0,
                        onTap: () => setState(() => _selected = visits[i]),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.farm});

  final Farm farm;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Owner / manager', farm.ownerManager),
      ('Contact', farm.contactPhone),
      ('County', farm.county),
      ('Sub-county', farm.subCounty),
      ('Village', farm.locationArea),
      ('Production system', farm.systemLabel),
      ('Registered by', farm.createdByName),
      ('Registered on', Fmt.date(farm.createdAt)),
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
                  child: Text(
                    r.$2.isEmpty ? '—' : r.$2,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LatestSnapshot extends StatelessWidget {
  const _LatestSnapshot({required this.latest});

  final Evaluation latest;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forTotalScore(latest.totalScore);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            RichText(
              text: TextSpan(
                text: '${latest.totalScore}',
                style: AppTheme.mono(size: 34, color: color)
                    .copyWith(letterSpacing: -1.4, height: 1),
                children: [
                  TextSpan(
                    text: ' / 35',
                    style:
                        AppTheme.mono(size: 14, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(latest.ratingLabel.toUpperCase(),
                  style: AppTheme.mono(size: 10.5, color: color)),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text('HERD', style: AppTheme.eyebrow),
        const SizedBox(height: 8),
        Wrap(
          spacing: 20,
          runSpacing: 10,
          children: [
            _Stat('Cows', latest.breedingCows),
            _Stat('Bulls', latest.bulls),
            _Stat('Calves', latest.calves),
            _Stat('Growers', latest.growersSteers),
            _Stat('Total', latest.totalHerd, color: AppColors.greenLight),
          ],
        ),
        const SizedBox(height: 16),
        Text('WEAKEST SECTIONS', style: AppTheme.eyebrow),
        const SizedBox(height: 8),
        ..._weakest(latest).map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(Sections.label(e.key),
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.text2),
                      overflow: TextOverflow.ellipsis),
                ),
                Text(
                  '${e.value}',
                  style: AppTheme.mono(
                      size: 12.5,
                      color: AppColors.forSectionScore(e.value)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The three lowest-scoring sections on this visit — where the farmer
  /// should start, which is the question a manager actually asks.
  static List<MapEntry<String, int>> _weakest(Evaluation v) {
    final entries = v.sections.entries
        .map((e) => MapEntry(e.key, e.value.score))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return entries.take(3).toList();
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.color});

  final String label;
  final int value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(Fmt.thousands(value),
            style: AppTheme.mono(size: 17, color: color ?? AppColors.text)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.muted)),
      ],
    );
  }
}

/// Total score per visit as vertical bars. Deliberately not a line chart:
/// visits are irregular events, not a continuous series, and a line implies
/// values existed between them.
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
                    // 35 is the maximum, so bar heights are comparable
                    // across farms, not just within one.
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
                    Text(
                      Fmt.shortDate(v.evaluationDate),
                      style: AppTheme.mono(size: 9.5, color: AppColors.muted),
                      overflow: TextOverflow.ellipsis,
                    ),
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

    // Only show a delta when the dates actually differ — two visits on the
    // same day produce an arbitrary sign, which is the known mobile bug.
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
              : const Border(
                  bottom: BorderSide(color: Color(0xFF262626))),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(Fmt.date(visit.evaluationDate),
                  style: AppTheme.mono(size: 12, color: AppColors.text2)),
            ),
            Expanded(
              child: Text(visit.eoName,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ),
            if (delta != null)
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Text(
                  '${delta >= 0 ? '+' : ''}$delta',
                  style: AppTheme.mono(
                    size: 12,
                    color: delta >= 0 ? AppColors.greenLight : AppColors.orange,
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