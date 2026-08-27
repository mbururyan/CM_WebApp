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
import '../widgets/panel.dart';
import 'visit_detail_page.dart';

/// Every submitted evaluation, filterable, with a read-only detail view.
///
/// Filtering happens in memory over the already-loaded set: instant, no
/// composite indexes, and the same filtered list is what the Excel export
/// will consume.
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
  int _days = 0; // 0 means no date limit

  /// Rows rendered before "Load more". Keeps a long table from becoming a
  /// wall of rows the GM has to scroll past.
  int _shown = _pageSize;

  Evaluation? _selected;

  static const _all = 'All';
  static const _pageSize = 25;

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
    final cutoff =
        _days == 0 ? null : now.subtract(Duration(days: _days));
    final q = _search.trim().toLowerCase();

    final rows = source.where((v) {
      if (cutoff != null && v.evaluationDate.isBefore(cutoff)) return false;
      if (_county != _all && v.county != _county) return false;
      if (_evaluator != _all && v.eoName != _evaluator) return false;
      if (_rating != _all && v.band != _rating) return false;
      if (q.isNotEmpty) {
        final hay =
            '${v.farmName} ${v.eoName} ${v.county} ${v.subCounty}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    rows.sort((a, b) {
      final byDate = b.evaluationDate.compareTo(a.evaluationDate);
      if (byDate != 0) return byDate;
      final x = a.createdAt, y = b.createdAt;
      if (x == null || y == null) return 0;
      return y.compareTo(x);
    });

    return rows;
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
              counties: _optionsFrom(all.map((v) => v.county)),
              evaluators: _optionsFrom(all.map((v) => v.eoName)),
              search: _search,
              county: _county,
              evaluator: _evaluator,
              rating: _rating,
              days: _days,
              onChanged: (f) => setState(() {
                _search = f.search;
                _county = f.county;
                _evaluator = f.evaluator;
                _rating = f.rating;
                _days = f.days;
                _shown = _pageSize; // a new filter starts at the top
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
                title: 'No visits match these filters',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      all.isEmpty
                          ? 'No submitted visits have reached the database yet.'
                          : 'Try widening the date range or clearing a filter.',
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
              _VisitTable(
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

  static List<String> _optionsFrom(Iterable<String> values) {
    final set = values.where((s) => s.isNotEmpty && s != '—').toSet().toList()
      ..sort();
    return [_all, ...set];
  }

  Future<void> _deleteVisit(Evaluation v) async {
    final reason = await ConfirmDelete.show(
      context,
      title: 'Delete this visit?',
      subject: '${v.farmName} · ${Fmt.date(v.evaluationDate)} · '
          'by ${v.eoName} · ${v.totalScore}/35',
      consequence:
          'The visit disappears from every figure on this dashboard and from '
          'the exports. A full copy is kept in the deletions log, so it can '
          'be rebuilt, but it will not come back on its own.',
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
      // Back to the table, and re-read so the counts are honest.
      setState(() {
        _selected = null;
        _future = DataService.loadAll();
      });
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
}

/// Bundle so the filter row reports all its state in one callback.
class FilterState {
  const FilterState({
    required this.search,
    required this.county,
    required this.evaluator,
    required this.rating,
    required this.days,
  });

  final String search;
  final String county;
  final String evaluator;
  final String rating;
  final int days;
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.counties,
    required this.evaluators,
    required this.search,
    required this.county,
    required this.evaluator,
    required this.rating,
    required this.days,
    required this.onChanged,
    required this.onExport,
  });

  final List<String> counties;
  final List<String> evaluators;
  final String search;
  final String county;
  final String evaluator;
  final String rating;
  final int days;
  final ValueChanged<FilterState> onChanged;
  final VoidCallback? onExport;

  FilterState _with({
    String? s,
    String? c,
    String? e,
    String? r,
    int? d,
  }) =>
      FilterState(
        search: s ?? search,
        county: c ?? county,
        evaluator: e ?? evaluator,
        rating: r ?? rating,
        days: d ?? days,
      );

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 240,
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search farm or evaluator',
              prefixIcon: Icon(Icons.search, size: 18, color: AppColors.muted),
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (v) => onChanged(_with(s: v)),
          ),
        ),
        _Dropdown(
          value: county,
          items: counties,
          onChanged: (v) => onChanged(_with(c: v)),
        ),
        _Dropdown(
          value: evaluator,
          items: evaluators,
          onChanged: (v) => onChanged(_with(e: v)),
        ),
        _Dropdown(
          value: _dayLabel(days),
          items: const [
            'All time',
            'Last 30 days',
            'Last 90 days',
            'Last 12 months',
          ],
          onChanged: (v) => onChanged(_with(d: _dayValue(v))),
        ),
        _Dropdown(
          value: rating == 'All' ? 'All ratings' : Fmt.humanise(rating),
          items: const ['All ratings', 'Poor', 'Fair', 'Good', 'Excellent'],
          onChanged: (v) => onChanged(
              _with(r: v == 'All ratings' ? 'All' : v.toLowerCase())),
        ),
        if (onExport != null)
          FilledButton.icon(
            onPressed: onExport,
            icon: const Icon(Icons.download_outlined, size: 16),
            label: const Text('Export to Excel'),
            style: FilledButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
      ],
    );
  }

  static String _dayLabel(int d) => switch (d) {
        30 => 'Last 30 days',
        90 => 'Last 90 days',
        365 => 'Last 12 months',
        _ => 'All time',
      };

  static int _dayValue(String label) => switch (label) {
        'Last 30 days' => 30,
        'Last 90 days' => 90,
        'Last 12 months' => 365,
        _ => 0,
      };
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.fill,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          items: items
              .map((i) => DropdownMenuItem(
                    value: i,
                    child: Text(i, style: const TextStyle(fontSize: 13)),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          isDense: true,
          dropdownColor: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          icon: const Icon(Icons.expand_more,
              size: 18, color: AppColors.muted),
        ),
      ),
    );
  }
}

class _VisitTable extends StatelessWidget {
  const _VisitTable({
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
          // Horizontal scroll rather than squeezing eight columns onto a
          // phone — a squashed table is unreadable, a scrollable one isn't.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.sizeOf(context).width > 900
                    ? MediaQuery.sizeOf(context).width - 300
                    : 760,
              ),
              child: Column(
                children: [
                  const _HeaderRow(),
                  for (final v in rows)
                    _Row(visit: v, onTap: () => onOpen(v)),
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

// Column widths shared by the header and every row so they stay aligned.
const _wFarm = 3;
const _wCounty = 2;
const _wEo = 2;
const _wDate = 2;
const _wHead = 1;

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    Widget h(String t, int flex, {TextAlign align = TextAlign.left}) =>
        Expanded(
          flex: flex,
          child: Text(t.toUpperCase(),
              textAlign: align, style: AppTheme.eyebrow),
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          h('Farm', _wFarm),
          h('County', _wCounty),
          h('Evaluator', _wEo),
          h('Date', _wDate),
          h('Head', _wHead, align: TextAlign.right),
          const SizedBox(width: 16),
          SizedBox(width: 56, child: Text('SCORE', style: AppTheme.eyebrow)),
          SizedBox(width: 92, child: Text('RATING', style: AppTheme.eyebrow)),
          const SizedBox(width: 28),
        ],
      ),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({required this.visit, required this.onTap});

  final Evaluation visit;
  final VoidCallback onTap;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.visit;
    final scoreColor = AppColors.forTotalScore(v.totalScore);

    Widget cell(String t, int flex,
            {TextAlign align = TextAlign.left,
            bool mono = false,
            FontWeight? weight}) =>
        Expanded(
          flex: flex,
          child: Text(
            t.isEmpty ? '—' : t,
            textAlign: align,
            overflow: TextOverflow.ellipsis,
            style: mono
                ? AppTheme.mono(size: 12.5, color: AppColors.text2)
                : TextStyle(fontSize: 13, fontWeight: weight),
          ),
        );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          color: _hover ? const Color(0xFF232323) : Colors.transparent,
          child: Row(
            children: [
              cell(v.farmName, _wFarm, weight: FontWeight.w500),
              cell(v.county, _wCounty),
              cell(v.eoName, _wEo),
              cell(Fmt.date(v.evaluationDate), _wDate, mono: true),
              cell(Fmt.thousands(v.totalHerd), _wHead,
                  align: TextAlign.right, mono: true),
              const SizedBox(width: 16),
              SizedBox(
                width: 56,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 42,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scoreColor,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      '${v.totalScore}',
                      style: AppTheme.mono(
                          size: 12.5,
                          weight: FontWeight.w600,
                          color: const Color(0xFF0D0D0D)),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 92,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      v.ratingLabel.toUpperCase(),
                      style: AppTheme.mono(size: 10, color: scoreColor),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 28,
                child: Icon(
                  Icons.chevron_right,
                  size: 17,
                  color: _hover ? AppColors.text2 : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}