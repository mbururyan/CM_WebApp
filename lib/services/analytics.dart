import '../models/evaluation.dart';
import '../models/farm.dart';
import 'config_service.dart';
import 'data_service.dart';

/// The date windows offered by the Overview filter.
enum DateWindow {
  week(7, 'Last 7 days'),
  month(30, 'Last 30 days'),
  quarter(90, 'Last 90 days'),
  year(365, 'Last year'),
  all(0, 'All time');

  const DateWindow(this.days, this.label);

  final int days;
  final String label;

  DateTime? cutoff(DateTime now) =>
      days == 0 ? null : now.subtract(Duration(days: days));
}

/// One row of the "where the herd is weakest" ranking.
class SectionAverage {
  const SectionAverage({
    required this.key,
    required this.label,
    required this.average,
    required this.sampleSize,
  });

  final String key;
  final String label;
  final double average;

  /// How many visits actually scored this section. Shown so a 2.1 built
  /// from three visits isn't read as a fleet-wide finding.
  final int sampleSize;
}

/// A farm and how long since anyone visited it.
class OverdueFarm {
  const OverdueFarm({
    required this.farm,
    required this.lastVisit,
    required this.daysSince,
  });

  final Farm farm;
  final DateTime? lastVisit;
  final int? daysSince;
}

/// A labelled magnitude, for the bar charts.
class Slice {
  const Slice(this.label, this.value, {this.sublabel});

  final String label;
  final num value;

  /// Optional second line, e.g. the county under a farm name.
  final String? sublabel;
}

/// All dashboard figures, computed in memory from a single FleetData load.
///
/// Pure computation — no Firestore, no widgets.
class Analytics {
  Analytics(
    this.data, {
    DateTime? now,
    int? overdueDays,
    this.window = DateWindow.all,
  })  : now = now ?? DateTime.now(),
        overdueDays = overdueDays ?? ConfigService.current.overdueDays;

  final FleetData data;
  final DateTime now;
  final int overdueDays;

  /// The active date filter. Every figure below except [farmCount] and the
  /// overdue list is computed over visits inside this window.
  final DateWindow window;

  /// Visits inside the window.
  ///
  /// The window is applied here, once, and everything downstream inherits
  /// it. That is what makes "head overseen" mean *head seen in this period*
  /// rather than head ever recorded — a farm not visited in the last 7 days
  /// contributes nothing to a 7-day view.
  late final List<Evaluation> _visits = () {
    final cut = window.cutoff(now);
    if (cut == null) return data.evaluations;
    return data.evaluations
        .where((v) => !v.evaluationDate.isBefore(cut))
        .toList();
  }();

  List<Evaluation> get visits => _visits;

  /// Visits in the window whose scores are on the CURRENT scheme.
  ///
  /// v1 scored each section as a 1-5 judgement; v2 has the sections count
  /// themselves and 0 is reachable. Averaging the two produces a number
  /// that describes neither. Every score figure below runs on this list;
  /// counts of activity — how many visits, by whom, how much head — run on
  /// the full one, because a v1 visit still happened.
  late final List<Evaluation> scoredVisits =
      _visits.where((v) => v.isCurrentScoring).toList();

  /// How many visits in the window are left out of the score figures.
  /// Surfaced in the UI so a lower visit count on the score panels reads
  /// as deliberate rather than as data loss.
  int get legacyExcluded => _visits.length - scoredVisits.length;

  /// Every current-scheme visit, ignoring the window — for the figures
  /// that are facts about a farm rather than about the filter.
  late final List<Evaluation> scoredEvaluations =
      data.evaluations.where((v) => v.isCurrentScoring).toList();

  // ---------- headline figures ----------

  /// Not windowed: the register is the register regardless of date.
  int get farmCount => data.farms.length;

  int get visitCount => _visits.length;

  int get visitsThisWeek {
    final start = _startOfWeek(now);
    return _visits.where((v) => !v.evaluationDate.isBefore(start)).length;
  }

  /// Null when there are no visits — a zero would read as "the fleet scores
  /// zero", which is a different and false claim.
  double? get averageScore {
    if (scoredVisits.isEmpty) return null;
    return scoredVisits.fold<int>(0, (a, v) => a + v.totalScore) /
        scoredVisits.length;
  }

  /// Change against the equally-sized period immediately before the window.
  /// Null for "all time", and null unless both periods have visits.
  double? get averageScoreChange {
    if (window.days == 0) return null;
    final d = Duration(days: window.days);
    final recent = _mean(_between(now.subtract(d), now));
    final prior =
        _mean(_between(now.subtract(d * 2), now.subtract(d)));
    if (recent == null || prior == null) return null;
    return recent - prior;
  }

  /// TRAP 1: herd counts live on visits, not farms. Summing every visit
  /// double-counts a farm visited twice, so take the latest visit per farm
  /// and sum those.
  int get totalHead =>
      latestVisitPerFarm.values.fold<int>(0, (a, v) => a + v.totalHerd);

  int get farmsCovered => latestVisitPerFarm.length;

  /// The herd split by class, from each farm's latest visit in the window.
  ///
  /// Same rule as [totalHead]: latest visit per farm, never a sum across
  /// visits, or a farm seen twice would contribute its animals twice.
  HerdBreakdown get herdBreakdown {
    var cows = 0, bulls = 0, calves = 0, growers = 0;
    for (final v in latestVisitPerFarm.values) {
      cows += v.breedingCows;
      bulls += v.bulls;
      calves += v.calves;
      growers += v.growersSteers;
    }
    return HerdBreakdown(
      breedingCows: cows,
      bulls: bulls,
      calves: calves,
      growersSteers: growers,
      farms: latestVisitPerFarm.length,
    );
  }

  // ---------- the latest-visit index ----------

  /// farm_id -> that farm's most recent visit within the window.
  ///
  /// TRAP 2: two visits to the same farm on the same day break a naive
  /// "latest" comparison, so ties fall through to created_at.
  late final Map<String, Evaluation> latestVisitPerFarm = () {
    final latest = <String, Evaluation>{};
    for (final v in _visits) {
      if (v.farmId.isEmpty) continue;
      final held = latest[v.farmId];
      if (held == null || _isNewer(v, held)) latest[v.farmId] = v;
    }
    return latest;
  }();

  static bool _isNewer(Evaluation candidate, Evaluation held) {
    final byDate = candidate.evaluationDate.compareTo(held.evaluationDate);
    if (byDate != 0) return byDate > 0;
    final a = candidate.createdAt, b = held.createdAt;
    if (a == null || b == null) return false;
    return a.isAfter(b);
  }

  // ---------- charts ----------

  /// Visits per evaluator, most first.
  List<Slice> get visitsByEvaluator {
    final counts = <String, int>{};
    for (final v in _visits) {
      final name = v.eoName.isEmpty ? '—' : v.eoName;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    final rows = counts.entries.map((e) => Slice(e.key, e.value)).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return rows;
  }

  /// Herd size per farm, from each farm's latest visit in the window.
  List<Slice> herdByFarm({int limit = 15}) {
    final rows = latestVisitPerFarm.values
        .map((v) => Slice(
              v.farmName,
              v.totalHerd,
              sublabel: v.county.isEmpty ? null : v.county,
            ))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return rows.take(limit).toList();
  }

  int get farmsWithHerdData => latestVisitPerFarm.length;

  /// Herd size per county, latest visit per farm.
  List<Slice> get herdByCounty {
    final byCounty = <String, int>{};
    for (final v in latestVisitPerFarm.values) {
      final c = v.county.isEmpty ? 'Unknown' : v.county;
      byCounty[c] = (byCounty[c] ?? 0) + v.totalHerd;
    }
    final rows = byCounty.entries.map((e) => Slice(e.key, e.value)).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return rows;
  }

  /// Average score per section, worst first.
  List<SectionAverage> get sectionRanking {
    final totals = <String, int>{};
    final counts = <String, int>{};

    for (final v in scoredVisits) {
      v.sectionScores.forEach((key, score) {
        totals[key] = (totals[key] ?? 0) + score;
        counts[key] = (counts[key] ?? 0) + 1;
      });
    }

    final rows = <SectionAverage>[];
    for (final key in Sections.keys) {
      final n = counts[key] ?? 0;
      if (n == 0) continue;
      rows.add(SectionAverage(
        key: key,
        label: Sections.label(key),
        average: totals[key]! / n,
        sampleSize: n,
      ));
    }
    rows.sort((a, b) => a.average.compareTo(b.average));
    return rows;
  }

  /// Visit counts per rating band. Always all four keys, in ramp order, so
  /// the segments keep their colours even when a band is empty.
  Map<String, int> get ratingMix {
    final mix = <String, int>{
      'poor': 0,
      'fair': 0,
      'good': 0,
      'excellent': 0,
    };
    for (final v in scoredVisits) {
      final band = Evaluation.bandFor(v.totalScore);
      mix[band] = (mix[band] ?? 0) + 1;
    }
    return mix;
  }

  // ---------- lists ----------

  List<Evaluation> recentVisits({int limit = 5}) {
    final sorted = [..._visits]..sort((a, b) {
        final byDate = b.evaluationDate.compareTo(a.evaluationDate);
        if (byDate != 0) return byDate;
        final x = a.createdAt, y = b.createdAt;
        if (x == null || y == null) return 0;
        return y.compareTo(x);
      });
    return sorted.take(limit).toList();
  }

  /// Farms not visited within [overdueDays].
  ///
  /// Deliberately computed against ALL visits, not the window: whether a
  /// farm is overdue is a fact about the calendar, not about the filter.
  /// Filtering it would make every farm look overdue on a 7-day view.
  List<OverdueFarm> overdueFarms({int? limit}) {
    final latestEver = <String, Evaluation>{};
    for (final v in data.evaluations) {
      if (v.farmId.isEmpty) continue;
      final held = latestEver[v.farmId];
      if (held == null || _isNewer(v, held)) latestEver[v.farmId] = v;
    }

    final rows = <OverdueFarm>[];
    for (final farm in data.farms) {
      final visit = latestEver[farm.id];
      if (visit == null) {
        rows.add(OverdueFarm(farm: farm, lastVisit: null, daysSince: null));
        continue;
      }
      final days = now.difference(visit.evaluationDate).inDays;
      if (days >= overdueDays) {
        rows.add(OverdueFarm(
            farm: farm, lastVisit: visit.evaluationDate, daysSince: days));
      }
    }

    rows.sort((a, b) {
      if (a.daysSince == null && b.daysSince == null) return 0;
      if (a.daysSince == null) return -1;
      if (b.daysSince == null) return 1;
      return b.daysSince!.compareTo(a.daysSince!);
    });

    return limit == null ? rows : rows.take(limit).toList();
  }

  // ---------- helpers ----------

  /// Current-scheme visits only: this feeds the period-on-period delta,
  /// and a v1 visit on either side of the comparison would invent a swing
  /// that is really just a change of measurement.
  List<Evaluation> _between(DateTime from, DateTime to) => data.evaluations
      .where((v) =>
          v.isCurrentScoring &&
          !v.evaluationDate.isBefore(from) &&
          v.evaluationDate.isBefore(to))
      .toList();

  double? _mean(List<Evaluation> list) {
    if (list.isEmpty) return null;
    return list.fold<int>(0, (a, v) => a + v.totalScore) / list.length;
  }

  static DateTime _startOfWeek(DateTime d) {
    final midnight = DateTime(d.year, d.month, d.day);
    return midnight.subtract(Duration(days: midnight.weekday - 1));
  }
}

/// The herd split by animal class.
class HerdBreakdown {
  const HerdBreakdown({
    required this.breedingCows,
    required this.bulls,
    required this.calves,
    required this.growersSteers,
    required this.farms,
  });

  final int breedingCows;
  final int bulls;
  final int calves;
  final int growersSteers;

  /// How many farms these counts came from — the denominator behind the
  /// averages, and the reason the total moves when the date filter does.
  final int farms;

  int get total => breedingCows + bulls + calves + growersSteers;

  /// Label, count, and share of the total, biggest first.
  List<(String, int, double)> get classes {
    final rows = <(String, int)>[
      ('Breeding cows', breedingCows),
      ('Growers / steers', growersSteers),
      ('Calves', calves),
      ('Bulls', bulls),
    ]..sort((a, b) => b.$2.compareTo(a.$2));

    final t = total;
    return rows
        .map((r) => (r.$1, r.$2, t == 0 ? 0.0 : r.$2 / t * 100))
        .toList();
  }

  /// Cows per bull. A standard herd-structure check — a ratio far above
  /// about 30:1 suggests the farm is under-served for breeding.
  double? get cowsPerBull =>
      bulls == 0 ? null : breedingCows / bulls;

  /// Calves per breeding cow, a rough proxy for calving rate.
  double? get calvesPerCow =>
      breedingCows == 0 ? null : calves / breedingCows;

  double get averagePerFarm => farms == 0 ? 0 : total / farms;
}