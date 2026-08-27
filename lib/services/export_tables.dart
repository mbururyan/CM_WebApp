import '../models/evaluation.dart';
import '../models/farm.dart';
import '../utils/formatters.dart';

/// A named grid ready to become a sheet or a CSV file.
class ExportTable {
  const ExportTable({
    required this.name,
    required this.headers,
    required this.rows,
  });

  /// Sheet name. Excel forbids : \ / ? * [ ] and caps it at 31 chars.
  final String name;

  final List<String> headers;
  final List<List<Object?>> rows;

  int get rowCount => rows.length;
}

/// Turns documents into flat tables. Pure Dart — no Firestore, no Flutter,
/// no file writing. That separation means the flattening can be reasoned
/// about (and later tested) without touching the browser.
class ExportTables {
  ExportTables._();

  /// Dates go out as ISO text, not Excel serial numbers.
  ///
  /// Excel serials are ambiguous across locales and Power BI has to be told
  /// how to read them; `2026-08-04` is unambiguous everywhere and sorts
  /// correctly as text. The cost is that Excel shows it left-aligned until
  /// the column is formatted, which is a fair trade for correctness.
  static String _iso(DateTime? d) {
    if (d == null) return '';
    return '${d.year}-${_two(d.month)}-${_two(d.day)}';
  }

  static String _isoStamp(DateTime? d) {
    if (d == null) return '';
    return '${_iso(d)} ${_two(d.hour)}:${_two(d.minute)}';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// Yes / No / blank. Blank means the question was never answered, which
  /// is different from "No" and must stay distinguishable in the export.
  static String _yn(dynamic v) {
    if (v is bool) return v ? 'Yes' : 'No';
    if (v == null) return '';
    return v.toString();
  }

  /// The answer ids each section carries, in a fixed order so the column
  /// layout is stable between exports even when a visit skipped a section.
  static const _answerIds = <String, List<String>>{
    'feeding': ['feed_plan', 'ration_stage', 'minerals', 'water', 'dry_season'],
    'feed_quality': [
      'forage',
      'concentrate',
      'storage',
      'hygiene',
      'consistency'
    ],
    'biosecurity': [
      'access',
      'footbath',
      'quarantine',
      'deworming',
      'isolation'
    ],
    'housing': ['space', 'bedding', 'ventilation', 'shade', 'handling'],
    'performance': ['scale', 'schedule', 'adg_calc', 'perf_records'],
    'records': ['breeding', 'health', 'feed', 'financial', 'mortality'],
  };

  /// Numeric KPIs on the performance section. Absent when unknown — never
  /// zero — so an empty cell here means "not measured", not "measured as 0".
  static const _perfKpis = [
    'weaning_weight',
    'adg',
    'slaughter_weight',
    'mortality_pct',
  ];

  // ---------------------------------------------------------------
  // 1. The wide sheet — one row per visit, the Google-Form layout.
  // ---------------------------------------------------------------

  static ExportTable evaluations(List<Evaluation> visits) {
    // Vaccination columns are built from the diseases actually present, so
    // EO-added custom diseases appear instead of being silently dropped.
    final diseases = <String>{};
    for (final v in visits) {
      for (final vac in v.vaccinations) {
        if (vac.disease.trim().isNotEmpty) diseases.add(vac.disease.trim());
      }
    }
    final diseaseList = diseases.toList()..sort();

    final headers = <String>[
      'visit_id',
      'farm_id',
      'farm_name',
      'county',
      'sub_county',
      'evaluator',
      'evaluation_date',
      'breeding_cows',
      'bulls',
      'calves',
      'growers_steers',
      'total_head',
      for (final key in Sections.keys) 'score_$key',
      'total_score',
      'rating',
      for (final entry in _answerIds.entries)
        for (final id in entry.value) '${entry.key}_$id',
      for (final kpi in _perfKpis) 'kpi_$kpi',
      for (final key in Sections.keys) 'note_$key',
      for (final d in diseaseList) ...[
        '${_slug(d)}_frequency',
        '${_slug(d)}_last_given',
        '${_slug(d)}_records',
      ],
      'strength_1',
      'strength_2',
      'strength_3',
      'improve_1',
      'improve_2',
      'improve_3',
      'recommendations',
      'status',
      'created_at',
    ];

    final rows = <List<Object?>>[];
    for (final v in visits) {
      final byDisease = {
        for (final vac in v.vaccinations) vac.disease.trim(): vac,
      };

      rows.add([
        v.id,
        v.farmId,
        v.farmName,
        v.county,
        v.subCounty,
        v.eoName,
        _iso(v.evaluationDate),
        v.breedingCows,
        v.bulls,
        v.calves,
        v.growersSteers,
        v.totalHerd,
        for (final key in Sections.keys) v.sections[key]?.score,
        v.totalScore,
        Fmt.humanise(v.band),
        for (final entry in _answerIds.entries)
          for (final id in entry.value)
            _yn(v.sections[entry.key]?.answers[id]),
        for (final kpi in _perfKpis) v.sections['performance']?.answers[kpi],
        for (final key in Sections.keys) v.sections[key]?.comment ?? '',
        for (final d in diseaseList) ...[
          byDisease[d] == null ? '' : Fmt.humanise(byDisease[d]!.frequency),
          byDisease[d] == null
              ? ''
              : (byDisease[d]!.dateUnknown
                  ? 'Not recalled'
                  : _iso(byDisease[d]!.lastAdministered)),
          byDisease[d] == null ? '' : (byDisease[d]!.recordsAvailable ? 'Yes' : 'No'),
        ],
        _at(v.keyStrengths, 0),
        _at(v.keyStrengths, 1),
        _at(v.keyStrengths, 2),
        _at(v.areasImprovement, 0),
        _at(v.areasImprovement, 1),
        _at(v.areasImprovement, 2),
        v.recommendations,
        v.status,
        _isoStamp(v.createdAt),
      ]);
    }

    return ExportTable(
      name: 'Evaluations',
      headers: headers,
      rows: rows,
    );
  }

  // ---------------------------------------------------------------
  // 2. Section scores, long format — the shape Power BI wants.
  // ---------------------------------------------------------------

  static ExportTable sectionScoresLong(List<Evaluation> visits) {
    final rows = <List<Object?>>[];
    for (final v in visits) {
      for (final key in Sections.keys) {
        final s = v.sections[key];
        if (s == null) continue;
        rows.add([
          v.id,
          v.farmId,
          v.farmName,
          v.county,
          v.eoName,
          _iso(v.evaluationDate),
          key,
          Sections.label(key),
          s.score,
        ]);
      }
    }

    return ExportTable(
      name: 'Section scores',
      headers: const [
        'visit_id',
        'farm_id',
        'farm_name',
        'county',
        'evaluator',
        'evaluation_date',
        'section_key',
        'section_label',
        'score',
      ],
      rows: rows,
    );
  }

  // ---------------------------------------------------------------
  // 3. Vaccinations, long format.
  // ---------------------------------------------------------------

  static ExportTable vaccinationsLong(List<Evaluation> visits) {
    final rows = <List<Object?>>[];
    for (final v in visits) {
      for (final vac in v.vaccinations) {
        rows.add([
          v.id,
          v.farmId,
          v.farmName,
          v.county,
          _iso(v.evaluationDate),
          vac.disease,
          Fmt.humanise(vac.frequency),
          vac.dateUnknown ? '' : _iso(vac.lastAdministered),
          vac.dateUnknown ? 'Yes' : 'No',
          vac.recordsAvailable ? 'Yes' : 'No',
        ]);
      }
    }

    return ExportTable(
      name: 'Vaccinations',
      headers: const [
        'visit_id',
        'farm_id',
        'farm_name',
        'county',
        'evaluation_date',
        'disease',
        'frequency',
        'last_administered',
        'date_unknown',
        'records_available',
      ],
      rows: rows,
    );
  }

  // ---------------------------------------------------------------
  // 4. Farm register, with latest-visit context.
  // ---------------------------------------------------------------

  static ExportTable farms(
    List<Farm> farms,
    Map<String, Evaluation> latestPerFarm, {
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final rows = <List<Object?>>[];

    for (final f in farms) {
      final last = latestPerFarm[f.id];
      rows.add([
        f.id,
        f.name,
        f.county,
        f.subCounty,
        f.locationArea,
        f.ownerManager,
        f.contactPhone,
        f.systemLabel,
        f.createdByName,
        _iso(f.createdAt),
        last == null ? 0 : 1,
        _iso(last?.evaluationDate),
        last?.totalScore,
        last == null ? '' : Fmt.humanise(last.band),
        // Herd is "as of the last visit" — the column name says so, because
        // a bare "total_head" invites everyone to read it as current.
        last?.totalHerd,
        last == null
            ? ''
            : today.difference(last.evaluationDate).inDays.toString(),
      ]);
    }

    return ExportTable(
      name: 'Farms',
      headers: const [
        'farm_id',
        'farm_name',
        'county',
        'sub_county',
        'village',
        'owner_manager',
        'contact_phone',
        'production_system',
        'registered_by',
        'registered_on',
        'has_been_visited',
        'last_visit_date',
        'last_visit_score',
        'last_visit_rating',
        'head_at_last_visit',
        'days_since_last_visit',
      ],
      rows: rows,
    );
  }

  // ---------------------------------------------------------------
  // 5. Officer activity.
  // ---------------------------------------------------------------

  static ExportTable officerActivity(List<Evaluation> visits) {
    final byOfficer = <String, List<Evaluation>>{};
    for (final v in visits) {
      byOfficer.putIfAbsent(v.eoName, () => []).add(v);
    }

    final rows = <List<Object?>>[];
    byOfficer.forEach((name, list) {
      final total = list.fold<int>(0, (a, v) => a + v.totalScore);
      final dates = list.map((v) => v.evaluationDate).toList()..sort();
      rows.add([
        name,
        list.length,
        (total / list.length).toStringAsFixed(2),
        list.map((v) => v.farmId).toSet().length,
        _iso(dates.first),
        _iso(dates.last),
      ]);
    });

    rows.sort((a, b) => (b[1] as int).compareTo(a[1] as int));

    return ExportTable(
      name: 'Officer activity',
      headers: const [
        'evaluator',
        'visits',
        'avg_score_given',
        'distinct_farms',
        'first_visit',
        'last_visit',
      ],
      rows: rows,
    );
  }

  // ---------------------------------------------------------------

  static String _at(List<String> list, int i) =>
      i < list.length ? list[i] : '';

  /// Disease name to a safe column prefix: "Black quarter / anthrax"
  /// becomes "black_quarter_anthrax".
  static String _slug(String s) {
    final cleaned = s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return cleaned.isEmpty ? 'disease' : cleaned;
  }
}