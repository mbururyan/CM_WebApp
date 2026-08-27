import 'package:flutter/material.dart';

import '../services/analytics.dart';
import '../services/data_service.dart';
import '../services/export_service.dart';
import '../services/export_tables.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/panel.dart';

/// Bulk data pulls. Open to everyone — officers included.
class ExportsPage extends StatefulWidget {
  const ExportsPage({super.key});

  @override
  State<ExportsPage> createState() => _ExportsPageState();
}

class _ExportsPageState extends State<ExportsPage> {
  late Future<FleetData> _future;

  int _days = 0;
  String _county = 'All counties';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = DataService.loadAll();
  }

  /// The same filter shape the Visits page uses, so a file pulled here and
  /// a file pulled there over the same range contain the same rows.
  FleetData _filtered(FleetData all) {
    final cutoff =
        _days == 0 ? null : DateTime.now().subtract(Duration(days: _days));

    final visits = all.evaluations.where((v) {
      if (cutoff != null && v.evaluationDate.isBefore(cutoff)) return false;
      if (_county != 'All counties' && v.county != _county) return false;
      return true;
    }).toList();

    final farms = _county == 'All counties'
        ? all.farms
        : all.farms.where((f) => f.county == _county).toList();

    return FleetData(farms: farms, evaluations: visits);
  }

  Future<void> _run(void Function() job, String what) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // Let the spinner paint before the encoder blocks the isolate.
      await Future<void>.delayed(const Duration(milliseconds: 16));
      job();
      if (mounted) _toast('$what downloaded.');
    } catch (e) {
      if (mounted) _toast('Export failed: $e', bad: true);
    } finally {
      if (mounted) setState(() => _busy = false);
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
            title: 'Could not load the data',
            child: Text('${snapshot.error}',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.text2, height: 1.6)),
          );
        }

        final all = snapshot.data!;
        final data = _filtered(all);
        final a = Analytics(data);
        final isWide = MediaQuery.sizeOf(context).width >= Layout.wideBreakpoint;

        final counties = <String>{
          'All counties',
          ...all.farms.map((f) => f.county).where((c) => c.isNotEmpty),
        }.toList()
          ..sort((x, y) => x == 'All counties' ? -1 : x.compareTo(y));

        final evals = ExportTables.evaluations(data.evaluations);
        final sections = ExportTables.sectionScoresLong(data.evaluations);
        final vaccs = ExportTables.vaccinationsLong(data.evaluations);
        final farms =
            ExportTables.farms(data.farms, a.latestVisitPerFarm);
        final officers = ExportTables.officerActivity(data.evaluations);

        final everything = [evals, sections, vaccs, farms, officers];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- filters ----
            Panel(
              title: 'What to include',
              note: 'These apply to every file on this page.',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Select(
                    value: _label(_days),
                    items: const [
                      'All time',
                      'Last 30 days',
                      'Last 90 days',
                      'Last 12 months',
                    ],
                    onChanged: (v) => setState(() => _days = _value(v)),
                  ),
                  _Select(
                    value: _county,
                    items: counties,
                    onChanged: (v) => setState(() => _county = v),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      '${data.evaluations.length} visits · ${data.farms.length} farms',
                      style: AppTheme.mono(size: 12, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ---- the one-click file ----
            Panel(
              title: 'Everything, one workbook',
              note: 'Five sheets: the wide evaluation layout, section scores '
                  'in long format, vaccinations, the farm register and '
                  'officer activity.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in everything)
                        _Tag('${t.name} · ${t.rowCount}'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _busy || data.evaluations.isEmpty
                        ? null
                        : () => _run(
                              () => ExportService.downloadWorkbook(
                                tables: everything,
                                filename:
                                    ExportService.stamped('cm-beef-full'),
                              ),
                              'Workbook',
                            ),
                    icon: _busy
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.download_outlined, size: 17),
                    label: const Text('Download .xlsx'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ---- individual tables ----
            Panel(
              title: 'Individual sheets',
              note: 'CSV, one table per file. Useful when a Power BI query '
                  'expects a single flat source.',
              child: Column(
                children: [
                  for (final t in everything)
                    _TableRow(
                      table: t,
                      isWide: isWide,
                      busy: _busy,
                      onDownload: () => _run(
                        () => ExportService.downloadCsv(
                          table: t,
                          filename: ExportService.stamped(
                              'cm-${_slug(t.name)}'),
                        ),
                        t.name,
                      ),
                    ),
                ],
              ),
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
                      'Dates export as plain text in YYYY-MM-DD form rather '
                      'than Excel serial numbers, so they read the same way '
                      'in Excel, Power BI and Google Sheets. Empty answer '
                      'cells mean the question was never answered — which is '
                      'not the same as "No".',
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

  static String _label(int d) => switch (d) {
        30 => 'Last 30 days',
        90 => 'Last 90 days',
        365 => 'Last 12 months',
        _ => 'All time',
      };

  static int _value(String label) => switch (label) {
        'Last 30 days' => 30,
        'Last 90 days' => 90,
        'Last 12 months' => 365,
        _ => 0,
      };

  static String _slug(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.table,
    required this.isWide,
    required this.busy,
    required this.onDownload,
  });

  final ExportTable table;
  final bool isWide;
  final bool busy;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF262626))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(table.name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  '${table.headers.length} columns',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Text(
            '${table.rowCount} rows',
            style: AppTheme.mono(size: 12, color: AppColors.text2),
          ),
          const SizedBox(width: 16),
          OutlinedButton(
            onPressed: busy || table.rowCount == 0 ? null : onDownload,
            style: OutlinedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: const Text('CSV'),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.fill,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: AppTheme.mono(size: 11, color: AppColors.text2)),
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