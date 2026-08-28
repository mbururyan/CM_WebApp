import '../models/evaluation.dart';
import '../models/farm.dart';

/// Everything the Farms screens need about one farm, computed once from its
/// visits.
///
/// Deliberately not windowed by the Overview's date filter — a farm page
/// answers "what do we know about this farm", which is a question about its
/// whole history.
class FarmStats {
  FarmStats({required this.farm, required List<Evaluation> visits})
      : visits = _sorted(visits);

  final Farm farm;

  /// Oldest first, so index order is chronological.
  final List<Evaluation> visits;

  static List<Evaluation> _sorted(List<Evaluation> v) {
    final list = [...v]..sort((a, b) {
        final byDate = a.evaluationDate.compareTo(b.evaluationDate);
        if (byDate != 0) return byDate;
        final x = a.createdAt, y = b.createdAt;
        if (x == null || y == null) return 0;
        return x.compareTo(y);
      });
    return list;
  }

  bool get everVisited => visits.isNotEmpty;

  int get visitCount => visits.length;

  Evaluation? get latest => visits.isEmpty ? null : visits.last;

  Evaluation? get previous =>
      visits.length < 2 ? null : visits[visits.length - 2];

  /// Herd at the most recent visit. Never a sum across visits — that would
  /// count the same animals once per visit.
  int? get herdSize => latest?.totalHerd;

  double? get averageScore {
    if (visits.isEmpty) return null;
    return visits.fold<int>(0, (a, v) => a + v.totalScore) / visits.length;
  }

  int? get latestScore => latest?.totalScore;

  int daysSinceLastVisit(DateTime now) =>
      latest == null ? -1 : now.difference(latest!.evaluationDate).inDays;

  /// Section averages across every visit to this farm, worst first.
  ///
  /// Averaged rather than taken from the latest visit: one bad day should
  /// not define a farm's weakest area, and one good day should not hide it.
  List<MapEntry<String, double>> get sectionAverages {
    final totals = <String, int>{};
    final counts = <String, int>{};
    for (final v in visits) {
      v.sectionScores.forEach((k, s) {
        totals[k] = (totals[k] ?? 0) + s;
        counts[k] = (counts[k] ?? 0) + 1;
      });
    }
    final rows = <MapEntry<String, double>>[];
    for (final key in Sections.keys) {
      final n = counts[key] ?? 0;
      if (n == 0) continue;
      rows.add(MapEntry(key, totals[key]! / n));
    }
    rows.sort((a, b) => a.value.compareTo(b.value));
    return rows;
  }

  MapEntry<String, double>? get weakest {
    final rows = sectionAverages;
    return rows.isEmpty ? null : rows.first;
  }

  MapEntry<String, double>? get strongest {
    final rows = sectionAverages;
    return rows.isEmpty ? null : rows.last;
  }

  /// Score change from the previous visit, or null when there is no
  /// previous visit — or when both fall on the same day, where the sign
  /// would be arbitrary.
  int? get trend {
    final a = previous, b = latest;
    if (a == null || b == null) return null;
    if (_sameDay(a.evaluationDate, b.evaluationDate)) return null;
    return b.totalScore - a.totalScore;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Build one per farm, joining the visit list by farm_id.
  static List<FarmStats> buildAll(
    List<Farm> farms,
    List<Evaluation> evaluations,
  ) {
    final byFarm = <String, List<Evaluation>>{};
    for (final v in evaluations) {
      byFarm.putIfAbsent(v.farmId, () => []).add(v);
    }
    return farms
        .map((f) => FarmStats(farm: f, visits: byFarm[f.id] ?? const []))
        .toList();
  }
}