import 'package:flutter/material.dart';

import '../models/evaluation.dart';
import '../services/analytics.dart';
import '../services/data_service.dart';
import '../services/export_service.dart';
import '../services/export_tables.dart';
import '../services/farm_stats.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/panel.dart';
import 'farm_detail_page.dart';

/// The farm register as a grid of cards. Each card carries enough to decide
/// whether to open it: herd, average score, visit count, and how long since
/// anyone was there.
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

  String? _selectedId;

  static const _all = 'All';
  static const _allFarms = 'All farms';
  static const _never = 'Never visited';
  static const _overdue = 'Overdue';

  @override
  void initState() {
    super.initState();
    _future = DataService.loadAll();
  }

  void _reload() => setState(() {
        _future = DataService.loadAll();
        _selectedId = null;
      });

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
        final all = FarmStats.buildAll(data.farms, data.evaluations);

        // Held by id, not by object, so the detail page survives a reload.
        if (_selectedId != null) {
          final match = all.where((s) => s.farm.id == _selectedId).toList();
          if (match.isNotEmpty) {
            return FarmDetailPage(
              stats: match.first,
              onBack: () => setState(() => _selectedId = null),
              onChanged: _reload,
            );
          }
          // The farm was deleted underneath us.
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => setState(() => _selectedId = null));
        }

        final rows = _apply(all);
        final overdueDays = ConfigDays.of(data);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Filters(
              counties: _options(data.farms.map((f) => f.county)),
              systems: _options(data.farms.map((f) => f.systemLabel)),
              county: _county,
              system: _system,
              coverage: _coverage,
              onSearch: (v) => setState(() => _search = v),
              onCounty: (v) => setState(() => _county = v),
              onSystem: (v) => setState(() => _system = v),
              onCoverage: (v) => setState(() => _coverage = v),
              onExport: rows.isEmpty
                  ? null
                  : () {
                      final latest = Analytics(data).latestVisitPerFarm;
                      ExportService.downloadCsv(
                        table: ExportTables.farms(
                            rows.map((s) => s.farm).toList(), latest),
                        filename: ExportService.stamped('cm-farms'),
                      );
                    },
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 12),
              child: Text(
                '${rows.length} of ${all.length} farms · '
                '${all.where((s) => !s.everVisited).length} never visited',
                style: AppTheme.mono(size: 12, color: AppColors.muted),
              ),
            ),
            if (rows.isEmpty)
              Panel(
                title: 'No farms match these filters',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      all.isEmpty
                          ? 'No farms have been registered yet.'
                          : 'Try clearing a filter.',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.text2, height: 1.6),
                    ),
                    if (all.isNotEmpty) ...[
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
              _CardGrid(
                rows: rows,
                overdueDays: overdueDays,
                onOpen: (s) => setState(() => _selectedId = s.farm.id),
              ),
          ],
        );
      },
    );
  }

  List<FarmStats> _apply(List<FarmStats> source) {
    final q = _search.trim().toLowerCase();
    final now = DateTime.now();

    final rows = source.where((s) {
      final f = s.farm;
      if (_county != _all && f.county != _county) return false;
      if (_system != _all && f.systemLabel != _system) return false;
      if (_coverage == _never && s.everVisited) return false;
      if (_coverage == _overdue) {
        if (!s.everVisited) return false;
        if (s.daysSinceLastVisit(now) < 90) return false;
      }
      if (q.isNotEmpty) {
        final hay =
            '${f.name} ${f.ownerManager} ${f.locationArea} ${f.county} ${f.subCounty}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    // Never-visited first — those are the actionable gaps — then by name.
    rows.sort((x, y) {
      final xv = x.everVisited ? 1 : 0;
      final yv = y.everVisited ? 1 : 0;
      if (xv != yv) return xv - yv;
      return x.farm.name.toLowerCase().compareTo(y.farm.name.toLowerCase());
    });

    return rows;
  }

  static List<String> _options(Iterable<String> values) {
    final set = values.where((s) => s.isNotEmpty && s != '—').toSet().toList()
      ..sort();
    return [_all, ...set];
  }
}

/// Small helper so the card grid can label the overdue badge with whatever
/// threshold Settings currently holds.
class ConfigDays {
  ConfigDays._();
  static int of(FleetData data) => Analytics(data).overdueDays;
}

class _CardGrid extends StatelessWidget {
  const _CardGrid({
    required this.rows,
    required this.overdueDays,
    required this.onOpen,
  });

  final List<FarmStats> rows;
  final int overdueDays;
  final ValueChanged<FarmStats> onOpen;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Cards want a minimum readable width; the column count follows from
    // that rather than from a breakpoint table.
    final columns = width >= 1180 ? 3 : (width >= 760 ? 2 : 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 14.0;
        final cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final s in rows)
              SizedBox(
                width: cardWidth,
                child: _FarmCard(
                  stats: s,
                  overdueDays: overdueDays,
                  onTap: () => onOpen(s),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FarmCard extends StatefulWidget {
  const _FarmCard({
    required this.stats,
    required this.overdueDays,
    required this.onTap,
  });

  final FarmStats stats;
  final int overdueDays;
  final VoidCallback onTap;

  @override
  State<_FarmCard> createState() => _FarmCardState();
}

class _FarmCardState extends State<_FarmCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.stats;
    final f = s.farm;
    final now = DateTime.now();
    final days = s.daysSinceLastVisit(now);
    final overdue = s.everVisited && days >= widget.overdueDays;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _hover ? const Color(0xFF232323) : AppColors.surface,
            border: Border.all(
                color: _hover ? const Color(0xFF4A4A4A) : AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ---- name + latest score ----
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.name,
                          style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [f.locationArea, f.county]
                              .where((x) => x.isNotEmpty)
                              .join(' · '),
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (s.latestScore != null)
                    Container(
                      width: 44,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.forTotalScore(s.latestScore!),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text('${s.latestScore}',
                          style: AppTheme.mono(
                              size: 13,
                              weight: FontWeight.w600,
                              color: const Color(0xFF0D0D0D))),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              if (!s.everVisited)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.fill,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    'Never visited · registered by ${f.createdByName}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else ...[
                Row(
                  children: [
                    _Metric(
                        label: 'Herd', value: Fmt.thousands(s.herdSize ?? 0)),
                    _Metric(
                      label: 'Avg score',
                      value: s.averageScore!.toStringAsFixed(1),
                      color: AppColors.forTotalScore(
                          s.averageScore!.round()),
                    ),
                    _Metric(label: 'Visits', value: '${s.visitCount}'),
                  ],
                ),
                const SizedBox(height: 14),
                _WeakStrong(stats: s),
              ],

              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    overdue ? Icons.schedule : Icons.check_circle_outline,
                    size: 13,
                    color: overdue ? AppColors.amber : AppColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      s.everVisited
                          ? 'Last visit ${Fmt.relative(s.latest!.evaluationDate, now: now)}'
                          : 'Registered ${Fmt.relative(f.createdAt, now: now)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: overdue ? AppColors.amber : AppColors.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (s.trend != null)
                    Text(
                      '${s.trend! >= 0 ? '+' : ''}${s.trend}',
                      style: AppTheme.mono(
                        size: 11.5,
                        color: s.trend! >= 0
                            ? AppColors.greenLight
                            : AppColors.orange,
                      ),
                    ),
                ],
              ),
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
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: AppTheme.mono(size: 16, color: color ?? AppColors.text)),
          const SizedBox(height: 2),
          Text(label.toUpperCase(), style: AppTheme.eyebrow),
        ],
      ),
    );
  }
}

/// Weakest and strongest section, side by side. Two words each — the card
/// is a decision aid, not a report.
class _WeakStrong extends StatelessWidget {
  const _WeakStrong({required this.stats});

  final FarmStats stats;

  @override
  Widget build(BuildContext context) {
    final weak = stats.weakest;
    final strong = stats.strongest;
    if (weak == null) return const SizedBox.shrink();

    Widget line(IconData icon, Color color, MapEntry<String, double> e) => Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                Sections.label(e.key),
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.text2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Text(e.value.toStringAsFixed(1),
                style: AppTheme.mono(size: 11.5, color: color)),
          ],
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        children: [
          line(Icons.arrow_downward, AppColors.orange, weak),
          if (strong != null && strong.key != weak.key) ...[
            const SizedBox(height: 7),
            line(Icons.arrow_upward, AppColors.greenLight, strong),
          ],
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.counties,
    required this.systems,
    required this.county,
    required this.system,
    required this.coverage,
    required this.onSearch,
    required this.onCounty,
    required this.onSystem,
    required this.onCoverage,
    required this.onExport,
  });

  final List<String> counties;
  final List<String> systems;
  final String county;
  final String system;
  final String coverage;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onCounty;
  final ValueChanged<String> onSystem;
  final ValueChanged<String> onCoverage;
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
            onChanged: onSearch,
          ),
        ),
        _Select(value: county, items: counties, onChanged: onCounty),
        _Select(value: system, items: systems, onChanged: onSystem),
        _Select(
          value: coverage,
          items: const ['All farms', 'Never visited', 'Overdue'],
          onChanged: onCoverage,
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