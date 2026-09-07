import 'package:flutter/material.dart';

import '../models/evaluation.dart';
import '../services/admin_service.dart';
import '../services/data_service.dart';
import '../services/export_service.dart';
import '../services/export_tables.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/filter_bar.dart';
import '../widgets/panel.dart';
import 'visit_detail_page.dart';

/// Every submitted evaluation, newest first, as a dense listing.
///
/// Column widths are FIXED rather than flexed. A horizontal scroll view
/// hands its child unbounded width, and Expanded inside unbounded width
/// throws — which is what left this table blank. Fixed widths also keep the
/// header and the rows aligned without a shared layout pass.
class VisitsPage extends StatefulWidget {
  const VisitsPage({super.key});

  @override
  State<VisitsPage> createState() => _VisitsPageState();
}

class _VisitsPageState extends State<VisitsPage> {
  late Future<FleetData> _future;

  String _search = '';
  String _county = _all;
  String _evaluator = _all;
  String _rating = _all;
  int _days = 0;
  int _shown = _pageSize;

  Evaluation? _selected;

  static const _all = 'All';
  static const _pageSize = 40;

  @override
  void initState() {
    super.initState();
    _future = DataService.loadAll();
  }

  void _reload() => setState(() {
        _future = DataService.loadAll();
        _selected = null;
      });

  List<Evaluation> _apply(List<Evaluation> source) {
    final now = DateTime.now();
    final cutoff = _days == 0 ? null : now.subtract(Duration(days: _days));
    final q = _search.trim().toLowerCase();

    final rows = source.where((v) {
      if (cutoff != null && v.evaluationDate.isBefore(cutoff)) return false;
      if (_county != _all && v.county != _county) return false;
      if (_evaluator != _all && v.eoName != _evaluator) return false;
      if (_rating != _all && v.band != _rating) return false;
      if (q.isNotEmpty) {
        final hay =
            '${v.farmName} ${v.eoName} ${v.county} ${v.subCounty}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    // Newest first, created_at breaking same-day ties.
    rows.sort((a, b) {
      final byDate = b.evaluationDate.compareTo(a.evaluationDate);
      if (byDate != 0) return byDate;
      final x = a.createdAt, y = b.createdAt;
      if (x == null || y == null) return 0;
      return y.compareTo(x);
    });

    return rows;
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
      _reload();
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
            title: 'Could not load visits',
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

        if (_selected != null) {
          return VisitDetailPage(
            visit: _selected!,
            onBack: () => setState(() => _selected = null),
            onDelete: SessionService.isAdmin
                ? () => _deleteVisit(_selected!)
                : null,
          );
        }

        final all = data.evaluations;
        final rows = _apply(all);
        final visible = rows.take(_shown).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Filters(
              counties: _options(all.map((v) => v.county)),
              evaluators: _options(all.map((v) => v.eoName)),
              county: _county,
              evaluator: _evaluator,
              rating: _rating,
              days: _days,
              search: _search,
              onSearch: (v) => setState(() {
                _search = v;
                _shown = _pageSize;
              }),
              onCounty: (v) => setState(() {
                _county = v;
                _shown = _pageSize;
              }),
              onEvaluator: (v) => setState(() {
                _evaluator = v;
                _shown = _pageSize;
              }),
              onRating: (v) => setState(() {
                _rating = v;
                _shown = _pageSize;
              }),
              onDays: (v) => setState(() {
                _days = v;
                _shown = _pageSize;
              }),
              onExport: rows.isEmpty
                  ? null
                  : () => ExportService.downloadWorkbook(
                        tables: [
                          ExportTables.evaluations(rows),
                          ExportTables.sectionScoresLong(rows),
                        ],
                        filename: ExportService.stamped('cm-beef-visits'),
                      ),
            ),
            const SizedBox(height: 14),
            if (rows.isEmpty)
              Panel(
                title: all.isEmpty
                    ? 'No submitted visits yet'
                    : 'No visits match these filters',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      all.isEmpty
                          ? 'Nothing has been submitted from the mobile app '
                              'yet. Drafts are deliberately excluded.'
                          : 'Try widening the period or clearing a filter.',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.text2, height: 1.6),
                    ),
                    if (all.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => setState(() {
                          _search = '';
                          _county = _all;
                          _evaluator = _all;
                          _rating = _all;
                          _days = 0;
                        }),
                        child: const Text('Clear filters'),
                      ),
                    ],
                  ],
                ),
              )
            else
              _Listing(
                rows: visible,
                total: rows.length,
                onOpen: (v) => setState(() => _selected = v),
                onLoadMore: visible.length < rows.length
                    ? () => setState(() => _shown += _pageSize)
                    : null,
              ),
          ],
        );
      },
    );
  }

  static List<String> _options(Iterable<String> values) {
    final set = values.where((s) => s.isNotEmpty && s != '—').toSet().toList()
      ..sort();
    return [_all, ...set];
  }
}

// ---------------------------------------------------------------------
// Column widths. One list, used by the header and every row, so they
// cannot drift apart.
// ---------------------------------------------------------------------

const _cFarm = 190.0;
const _cCounty = 115.0;
const _cSub = 110.0;
const _cEo = 135.0;
const _cHerd = 58.0;
const _cTotal = 70.0;
const _cDate = 108.0;
const _cScore = 62.0;
const _cRating = 92.0;
const _cChevron = 30.0;

const _tableWidth = _cFarm +
    _cCounty +
    _cSub +
    _cEo +
    _cHerd * 4 +
    _cTotal +
    _cDate +
    _cScore +
    _cRating +
    _cChevron +
    14 +
    32; // horizontal padding

class _Listing extends StatelessWidget {
  const _Listing({
    required this.rows,
    required this.total,
    required this.onOpen,
    required this.onLoadMore,
  });

  final List<Evaluation> rows;
  final int total;
  final ValueChanged<Evaluation> onOpen;
  final VoidCallback? onLoadMore;

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
          LayoutBuilder(
            builder: (context, constraints) {
              // Stretch to fill when there is room, scroll when there isn't.
              final width = constraints.maxWidth > _tableWidth
                  ? constraints.maxWidth
                  : _tableWidth;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  child: Column(
                    children: [
                      const _HeaderRow(),
                      for (var i = 0; i < rows.length; i++)
                        _Row(
                          visit: rows[i],
                          striped: i.isOdd,
                          onTap: () => onOpen(rows[i]),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Text(
                  rows.length == total
                      ? '$total ${total == 1 ? "visit" : "visits"}'
                      : 'Showing ${rows.length} of $total',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const Spacer(),
                if (onLoadMore != null)
                  OutlinedButton(
                    onPressed: onLoadMore,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                    child: const Text('Load more'),
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
    Widget h(String t, double w, {TextAlign align = TextAlign.left}) =>
        SizedBox(
          width: w,
          child: Text(t.toUpperCase(),
              textAlign: align, style: AppTheme.eyebrow),
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: const BoxDecoration(
        color: Color(0xFF202020),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          h('Farm', _cFarm),
          h('County', _cCounty),
          h('Sub-county', _cSub),
          h('Evaluator', _cEo),
          h('Cows', _cHerd, align: TextAlign.right),
          h('Bulls', _cHerd, align: TextAlign.right),
          h('Calves', _cHerd, align: TextAlign.right),
          h('Growers', _cHerd, align: TextAlign.right),
          h('Head', _cTotal, align: TextAlign.right),
          const SizedBox(width: 14),
          h('Visited', _cDate),
          h('Score', _cScore),
          h('Rating', _cRating),
          const SizedBox(width: _cChevron),
        ],
      ),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({
    required this.visit,
    required this.striped,
    required this.onTap,
  });

  final Evaluation visit;

  /// Alternating tint — at a dozen columns the eye loses the line without it.
  final bool striped;

  final VoidCallback onTap;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.visit;
    final color = AppColors.forTotalScore(v.totalScore);

    Widget text(String t, double w,
            {TextAlign align = TextAlign.left,
            bool mono = false,
            Color? c,
            FontWeight? weight}) =>
        SizedBox(
          width: w,
          child: Text(
            t.isEmpty ? '—' : t,
            textAlign: align,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: mono
                ? AppTheme.mono(size: 12, color: c ?? AppColors.text2)
                : TextStyle(
                    fontSize: 12.5,
                    fontWeight: weight,
                    color: c ?? AppColors.text),
          ),
        );

    // A herd class of zero is real information, but printing "0" four times
    // per row is noise — a dash reads faster.
    Widget count(int n) => text(n == 0 ? '–' : Fmt.thousands(n), _cHerd,
        align: TextAlign.right,
        mono: true,
        c: n == 0 ? AppColors.muted : AppColors.text2);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: _hover
                ? const Color(0xFF2A2A2A)
                : (widget.striped
                    ? const Color(0xFF1B1B1B)
                    : Colors.transparent),
            border: const Border(
                bottom: BorderSide(color: Color(0xFF262626))),
          ),
          child: Row(
            children: [
              text(v.farmName, _cFarm, weight: FontWeight.w500),
              text(v.county, _cCounty, c: AppColors.text2),
              text(v.subCounty, _cSub, c: AppColors.text2),
              text(v.eoName, _cEo, c: AppColors.text2),
              count(v.breedingCows),
              count(v.bulls),
              count(v.calves),
              count(v.growersSteers),
              text(Fmt.thousands(v.totalHerd), _cTotal,
                  align: TextAlign.right, mono: true, c: AppColors.text),
              const SizedBox(width: 14),
              text(Fmt.date(v.evaluationDate), _cDate, mono: true),
              SizedBox(
                width: _cScore,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 42,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${v.totalScore}',
                        style: AppTheme.mono(
                            size: 12,
                            weight: FontWeight.w600,
                            color: const Color(0xFF0D0D0D))),
                  ),
                ),
              ),
              SizedBox(
                width: _cRating,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(v.ratingLabel.toUpperCase(),
                        style: AppTheme.mono(size: 9.5, color: color)),
                  ),
                ),
              ),
              SizedBox(
                width: _cChevron,
                child: Icon(Icons.chevron_right,
                    size: 16,
                    color: _hover ? AppColors.text2 : AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.counties,
    required this.evaluators,
    required this.county,
    required this.evaluator,
    required this.rating,
    required this.days,
    required this.search,
    required this.onSearch,
    required this.onCounty,
    required this.onEvaluator,
    required this.onRating,
    required this.onDays,
    required this.onExport,
  });

  final List<String> counties;
  final List<String> evaluators;
  final String county;
  final String evaluator;
  final String rating;
  final int days;
  final String search;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onCounty;
  final ValueChanged<String> onEvaluator;
  final ValueChanged<String> onRating;
  final ValueChanged<int> onDays;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    return FilterBar(
      children: [
        FilterSearch(
          hint: 'Search farm or evaluator',
          value: search,
          onChanged: onSearch,
          width: 240,
        ),
        FilterSelect(
            label: 'County',
            value: county,
            items: counties,
            onChanged: onCounty),
        FilterSelect(
            label: 'Evaluator',
            value: evaluator,
            items: evaluators,
            onChanged: onEvaluator),
        FilterSelect(
          label: 'Period',
          value: FilterPeriod.label(days),
          items: FilterPeriod.options,
          onChanged: (v) => onDays(FilterPeriod.days(v)),
        ),
        FilterSelect(
          label: 'Rating',
          value: rating == 'All' ? 'All' : Fmt.humanise(rating),
          items: const ['All', 'Poor', 'Fair', 'Good', 'Excellent'],
          onChanged: (v) => onRating(v == 'All' ? 'All' : v.toLowerCase()),
        ),
        if (onExport != null) FilterExportButton(onPressed: onExport),
      ],
    );
  }
}