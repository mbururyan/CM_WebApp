import '../models/evaluation.dart';
import '../models/farm.dart';
import 'config_service.dart';
import 'data_service.dart';

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

  /// Null when the farm has never been visited.
  final DateTime? lastVisit;

  /// Days since the last visit, or null if never visited.
  final int? daysSince;
}

/// All dashboard figures, computed in memory from a single FleetData load.
///
/// Pure computation — no Firestore, no widgets. Every number the GM sees on
/// Monday comes out of this class.
class Analytics {
  Analytics(this.data, {DateTime? now, int? overdueDays})
      : now = now ?? DateTime.now(),
        overdueDays = overdueDays ?? ConfigService.current.overdueDays;

  final FleetData data;
  final DateTime now;
  final int overdueDays;

  List<Evaluation> get _visits => data.evaluations;

  // ---------- headline figures ----------

  int get farmCount => data.farms.length;

  int get visitCount => _visits.length;

  int get visitsThisWeek {
    final start = _startOfWeek(now);
    return _visits.where((v) => !v.evaluationDate.isBefore(start)).length;
  }

  /// Mean total score across every submitted visit, or null when there are
  /// none — a zero here would read as "the fleet scores 0", which is a lie.
  double? get averageScore {
    if (_visits.isEmpty) return null;
    final sum = _visits.fold<int>(0, (a, v) => a + v.totalScore);
    return sum / _visits.length;
  }

  /// Change in average score, last 30 days versus the 30 before that.
  /// Null unless both windows have visits.
  double? get averageScoreChange {
    final recent = _mean(_between(now.subtract(const Duration(days: 30)), now));
    final prior = _mean(_between(
      now.subtract(const Duration(days: 60)),
      now.subtract(const Duration(days: 30)),
    ));
    if (recent == null || prior == null) return null;
    return recent - prior;
  }

  /// TRAP 1: herd counts live on visits, not farms. Summing every visit
  /// double-counts a farm visited twice. Take the latest visit per farm,
  /// then sum those.
  int get totalHead =>
      latestVisitPerFarm.values.fold<int>(0, (a, v) => a + v.totalHerd);

  /// Farms with at least one submitted visit.
  int get farmsCovered => latestVisitPerFarm.length;

  // ---------- the latest-visit index ----------

  /// farm_id -> that farm's most recent submitted visit.
  ///
  /// TRAP 2: two visits to the same farm on the same day break a naive
  /// "latest" comparison, so ties fall through to created_at. If both are
  /// missing created_at the incumbent wins, which is at least stable.
  Map<String, Evaluation> get latestVisitPerFarm {
    final latest = <String, Evaluation>{};
    for (final v in _visits) {
      if (v.farmId.isEmpty) continue;
      final held = latest[v.farmId];
      if (held == null || _isNewer(v, held)) latest[v.farmId] = v;
    }
    return latest;
  }

  static bool _isNewer(Evaluation candidate, Evaluation held) {
    final byDate = candidate.evaluationDate.compareTo(held.evaluationDate);
    if (byDate != 0) return byDate > 0;

    final a = candidate.createdAt;
    final b = held.createdAt;
    if (a == null || b == null) return false;
    return a.isAfter(b);
  }

  // ---------- section ranking ----------

  /// Average score per section across all submitted visits, worst first.
  /// The most useful number in the product: it says where the systemic
  /// weakness is, which is something FCL can act on.
  List<SectionAverage> get sectionRanking {
    final totals = <String, int>{};
    final counts = <String, int>{};

    for (final v in _visits) {
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

  // ---------- distributions ----------

  /// rating -> count, always containing all four keys so the bar renders
  /// with stable segment order even when a band is empty.
  Map<String, int> get ratingMix {
    final mix = <String, int>{
      'excellent': 0,
      'good': 0,
      'fair': 0,
      'poor': 0,
    };
    for (final v in _visits) {
      final band = Evaluation.bandFor(v.totalScore);
      mix[band] = (mix[band] ?? 0) + 1;
    }
    return mix;
  }

  /// county -> head count, from the latest visit per farm, biggest first.
  List<MapEntry<String, int>> get headByCounty {
    final byCounty = <String, int>{};
    for (final v in latestVisitPerFarm.values) {
      final county = v.county.isEmpty ? 'Unknown' : v.county;
      byCounty[county] = (byCounty[county] ?? 0) + v.totalHerd;
    }
    final rows = byCounty.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return rows;
  }

  /// Visit counts for the last [weeks] weeks, oldest first.
  List<int> visitsPerWeek({int weeks = 8}) {
    final startOfThisWeek = _startOfWeek(now);
    final buckets = List<int>.filled(weeks, 0);

    for (final v in _visits) {
      final diff = startOfThisWeek.difference(_startOfWeek(v.evaluationDate));
      final weeksAgo = (diff.inDays / 7).round();
      if (weeksAgo < 0 || weeksAgo >= weeks) continue;
      buckets[weeks - 1 - weeksAgo] += 1;
    }
    return buckets;
  }

  // ---------- lists ----------

  /// Newest visits first.
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

  /// Farms not visited within [overdueDays], never-visited ones first,
  /// then longest-waiting.
  List<OverdueFarm> overdueFarms({int? limit}) {
    final latest = latestVisitPerFarm;
    final rows = <OverdueFarm>[];

    for (final farm in data.farms) {
      final visit = latest[farm.id];
      if (visit == null) {
        rows.add(OverdueFarm(farm: farm, lastVisit: null, daysSince: null));
        continue;
      }
      final days = now.difference(visit.evaluationDate).inDays;
      if (days >= overdueDays) {
        rows.add(OverdueFarm(
          farm: farm,
          lastVisit: visit.evaluationDate,
          daysSince: days,
        ));
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

  List<Evaluation> _between(DateTime from, DateTime to) => _visits
      .where((v) =>
          !v.evaluationDate.isBefore(from) && v.evaluationDate.isBefore(to))
      .toList();

  double? _mean(List<Evaluation> list) {
    if (list.isEmpty) return null;
    return list.fold<int>(0, (a, v) => a + v.totalScore) / list.length;
  }

  /// Monday 00:00 of the week containing [d].
  static DateTime _startOfWeek(DateTime d) {
    final midnight = DateTime(d.year, d.month, d.day);
    return midnight.subtract(Duration(days: midnight.weekday - 1));
  }
}