import 'package:flutter/material.dart';

import '../models/evaluation.dart';
import '../models/farm.dart';
import '../services/analytics.dart';
import '../services/data_service.dart';
import '../services/export_service.dart';
import '../services/export_tables.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/panel.dart';
import 'farm_detail_page.dart';

/// The farm register, filterable, with a detail view per farm.
class FarmsPage extends StatefulWidget {
  const FarmsPage({super.key});

  @override
  State<FarmsPage> createState() => _FarmsPageState();
}

class _FarmsPageState extends State<FarmsPage> {
  late Future<FleetData> _future;

  String _search = '';
  String _county = _all;
  String _system = _all;
  String _coverage = _allFarms;

  Farm? _selected;

  static const _all = 'All';
  static const _allFarms = 'All farms';
  static const _never = 'Never visited';
  static const _overdue = 'Overdue 90+ days';

  @override
  void initState() {
    super.initState();
    _future = DataService.loadAll();
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
            title: 'Could not load farms',
            child: Text('${snapshot.error}',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.text2, height: 1.6)),
          );
        }

        final data = snapshot.data!;
        final a = Analytics(data);
        final latest = a.latestVisitPerFarm;

        // farm_id -> its visits, built once instead of scanning per row.
        final byFarm = <String, List<Evaluation>>{};
        for (final v in data.evaluations) {
          byFarm.putIfAbsent(v.farmId, () => []).add(v);
        }

        if (_selected != null) {
          return FarmDetailPage(
            farm: _selected!,
            visits: byFarm[_selected!.id] ?? const [],
            onBack: () => setState(() => _selected = null),
            // After a delete: drop back to the table and re-read, so the
            // counts and the never-visited badges are honest again.
            onChanged: () => setState(() {
              _selected = null;
              _future = DataService.loadAll();
            }),
          );
        }

        final rows = _apply(data.farms, latest);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Filters(
              counties: _options(data.farms.map((f) => f.county)),
              systems: _options(data.farms.map((f) => f.systemLabel)),
              search: _search,
              county: _county,
              system: _system,
              coverage: _coverage,
              onChanged: (s, c, sy, cov) => setState(() {
                _search = s;
                _county = c;
                _system = sy;
                _coverage = cov;
              }),
              onExport: rows.isEmpty
                  ? null
                  : () => ExportService.downloadCsv(
                        table: ExportTables.farms(rows, latest),
                        filename: ExportService.stamped('cm-farms'),
                      ),
            ),
            const SizedBox(height: 14),
            if (rows.isEmpty)
              Panel(
                title: 'No farms match these filters',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.farms.isEmpty
                          ? 'No farms have been registered yet.'
                          : 'Try clearing a filter.',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.text2, height: 1.6),
                    ),
                    if (data.farms.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => setState(() {
                          _search = '';
                          _county = _all;
                          _system = _all;
                          _coverage = _allFarms;
                        }),
                        child: const Text('Clear filters'),
                      ),
                    ],
                  ],
                ),
              )
            else
              _FarmTable(
                farms: rows,
                latest: latest,
                byFarm: byFarm,
                neverVisited:
                    data.farms.where((f) => !latest.containsKey(f.id)).length,
                onOpen: (f) => setState(() => _selected = f),
              ),
          ],
        );
      },
    );
  }

  List<Farm> _apply(List<Farm> source, Map<String, Evaluation> latest) {
    final q = _search.trim().toLowerCase();
    final now = DateTime.now();

    final rows = source.where((f) {
      if (_county != _all && f.county != _county) return false;
      if (_system != _all && f.systemLabel != _system) return false;

      final last = latest[f.id];
      if (_coverage == _never && last != null) return false;
      if (_coverage == _overdue) {
        if (last == null) return false; // never-visited has its own filter
        if (now.difference(last.evaluationDate).inDays < 90) return false;
      }

      if (q.isNotEmpty) {
        final hay =
            '${f.name} ${f.ownerManager} ${f.locationArea} ${f.county} ${f.subCounty}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    // Never-visited farms first — the actionable ones — then by name.
    rows.sort((x, y) {
      final xv = latest.containsKey(x.id) ? 1 : 0;
      final yv = latest.containsKey(y.id) ? 1 : 0;
      if (xv != yv) return xv - yv;
      return x.name.toLowerCase().compareTo(y.name.toLowerCase());
    });

    return rows;
  }

  static List<String> _options(Iterable<String> values) {
    final set = values.where((s) => s.isNotEmpty && s != '—').toSet().toList()
      ..sort();
    return [_all, ...set];
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.counties,
    required this.systems,
    required this.search,
    required this.county,
    required this.system,
    required this.coverage,
    required this.onChanged,
    required this.onExport,
  });

  final List<String> counties;
  final List<String> systems;
  final String search;
  final String county;
  final String system;
  final String coverage;
  final void Function(String, String, String, String) onChanged;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 250,
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search farm, owner or village',
              prefixIcon: Icon(Icons.search, size: 18, color: AppColors.muted),
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (v) => onChanged(v, county, system, coverage),
          ),
        ),
        _Select(
          value: county,
          items: counties,
          onChanged: (v) => onChanged(search, v, system, coverage),
        ),
        _Select(
          value: system,
          items: systems,
          onChanged: (v) => onChanged(search, county, v, coverage),
        ),
        _Select(
          value: coverage,
          items: const ['All farms', 'Never visited', 'Overdue 90+ days'],
          onChanged: (v) => onChanged(search, county, system, v),
        ),
        if (onExport != null)
          OutlinedButton.icon(
            onPressed: onExport,
            icon: const Icon(Icons.download_outlined, size: 16),
            label: const Text('Export'),
          ),
      ],
    );
  }
}

class _Select extends StatelessWidget {
  const _Select({
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
          icon: const Icon(Icons.expand_more, size: 18, color: AppColors.muted),
        ),
      ),
    );
  }
}

class _FarmTable extends StatelessWidget {
  const _FarmTable({
    required this.farms,
    required this.latest,
    required this.byFarm,
    required this.neverVisited,
    required this.onOpen,
  });

  final List<Farm> farms;
  final Map<String, Evaluation> latest;
  final Map<String, List<Evaluation>> byFarm;
  final int neverVisited;
  final ValueChanged<Farm> onOpen;

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
                    : 800,
              ),
              child: Column(
                children: [
                  const _HeaderRow(),
                  for (final f in farms)
                    _Row(
                      farm: f,
                      latest: latest[f.id],
                      history: byFarm[f.id] ?? const [],
                      onTap: () => onOpen(f),
                    ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Text(
              '${farms.length} ${farms.length == 1 ? "farm" : "farms"}'
              '${neverVisited > 0 ? " · $neverVisited never visited" : ""}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

const _wName = 3;
const _wCounty = 2;
const _wSystem = 2;
const _wBy = 2;

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    Widget h(String t, int flex) => Expanded(
          flex: flex,
          child: Text(t.toUpperCase(), style: AppTheme.eyebrow),
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          h('Farm', _wName),
          h('County', _wCounty),
          h('System', _wSystem),
          h('Registered by', _wBy),
          SizedBox(width: 52, child: Text('VISITS', style: AppTheme.eyebrow)),
          SizedBox(width: 74, child: Text('TREND', style: AppTheme.eyebrow)),
          SizedBox(width: 108, child: Text('LATEST', style: AppTheme.eyebrow)),
          const SizedBox(width: 28),
        ],
      ),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({
    required this.farm,
    required this.latest,
    required this.history,
    required this.onTap,
  });

  final Farm farm;
  final Evaluation? latest;
  final List<Evaluation> history;
  final VoidCallback onTap;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.farm;
    final last = widget.latest;

    Widget cell(String t, int flex, {FontWeight? weight}) => Expanded(
          flex: flex,
          child: Text(
            t.isEmpty ? '—' : t,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: weight),
          ),
        );

    final sorted = [...widget.history]
      ..sort((a, b) => a.evaluationDate.compareTo(b.evaluationDate));

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
              Expanded(
                flex: _wName,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.name,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis),
                    if (f.locationArea.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(f.locationArea,
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.muted),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              cell(f.county, _wCounty),
              cell(f.systemLabel, _wSystem),
              cell(f.createdByName, _wBy),
              SizedBox(
                width: 52,
                child: Text('${widget.history.length}',
                    style: AppTheme.mono(
                        size: 12.5, color: AppColors.text2)),
              ),
              SizedBox(
                width: 74,
                child: _Sparkline(visits: sorted),
              ),
              SizedBox(
                width: 108,
                child: last == null
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.fill,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('NEVER VISITED',
                            style: AppTheme.mono(
                                size: 9.5, color: AppColors.muted)),
                      )
                    : Row(
                        children: [
                          Container(
                            width: 40,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color:
                                  AppColors.forTotalScore(last.totalScore),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('${last.totalScore}',
                                style: AppTheme.mono(
                                    size: 12,
                                    weight: FontWeight.w600,
                                    color: const Color(0xFF0D0D0D))),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              Fmt.shortDate(last.evaluationDate),
                              style: AppTheme.mono(
                                  size: 11, color: AppColors.muted),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              ),
              SizedBox(
                width: 28,
                child: Icon(Icons.chevron_right,
                    size: 17,
                    color: _hover ? AppColors.text2 : AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Total score per visit, oldest to newest. Shows whether a farm is moving
/// without needing to open it.
class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.visits});

  final List<Evaluation> visits;

  @override
  Widget build(BuildContext context) {
    if (visits.isEmpty) {
      return Text('—',
          style: AppTheme.mono(size: 12, color: AppColors.muted));
    }

    return SizedBox(
      height: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final v in visits.take(8))
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Container(
                width: 5,
                height: (v.totalScore / 35 * 22).clamp(2, 22),
                decoration: BoxDecoration(
                  color: AppColors.forTotalScore(v.totalScore),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}