import '../models/app_user.dart';
import '../models/evaluation.dart';
import '../models/farm.dart';
import 'data_service.dart';

/// Everything known about one officer, assembled from their visits.
class OfficerStats {
  OfficerStats({
    required this.user,
    required List<Evaluation> visits,
    required this.farmsRegistered,
  }) : visits = _sorted(visits);

  final AppUser user;

  /// Oldest first.
  final List<Evaluation> visits;

  /// Farms this person registered — not the same as farms they evaluated.
  final int farmsRegistered;

  static List<Evaluation> _sorted(List<Evaluation> v) {
    final list = [...v]
      ..sort((a, b) => a.evaluationDate.compareTo(b.evaluationDate));
    return list;
  }

  int get visitCount => visits.length;

  bool get hasVisits => visits.isNotEmpty;

  /// Distinct farms evaluated. Three visits to one farm is one farm.
  int get distinctFarms => visits.map((v) => v.farmId).toSet().length;

  double? get avgScoreGiven {
    if (visits.isEmpty) return null;
    return visits.fold<int>(0, (a, v) => a + v.totalScore) / visits.length;
  }

  DateTime? get firstVisit => visits.isEmpty ? null : visits.first.evaluationDate;

  DateTime? get lastActive => visits.isEmpty ? null : visits.last.evaluationDate;

  /// Total head across the officer's coverage — latest visit per farm, so a
  /// farm they visited three times counts its animals once.
  int get headCovered {
    final latest = <String, Evaluation>{};
    for (final v in visits) {
      final held = latest[v.farmId];
      if (held == null || v.evaluationDate.isAfter(held.evaluationDate)) {
        latest[v.farmId] = v;
      }
    }
    return latest.values.fold<int>(0, (a, v) => a + v.totalHerd);
  }

  /// Visits per month, measured from the officer's FIRST VISIT rather than
  /// their account creation date.
  ///
  /// An account opened in June by someone who started fieldwork in August
  /// would otherwise carry two dead months that drag the rate down and say
  /// nothing true about how they work.
  double? avgVisitsPerMonth(DateTime now) {
    if (visits.isEmpty) return null;
    final days = now.difference(firstVisit!).inDays;
    // Anything under a month is reported as the raw count rather than
    // extrapolated — three visits in a week is not twelve a month.
    final months = (days / 30.44);
    if (months < 1) return visitCount.toDouble();
    return visitCount / months;
  }

  /// Idle when nothing has been submitted in 30 days. Not the same as
  /// deactivated: the account is fine, the fieldwork has paused.
  bool isIdle(DateTime now) {
    if (lastActive == null) return true;
    return now.difference(lastActive!).inDays > 30;
  }

  /// The officer's average per section, worst first.
  ///
  /// This is a calibration view, not a judgement of the farms: an officer
  /// who scores biosecurity far below everyone else may be reading the
  /// rubric differently.
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

  /// Visit counts per calendar month for the last [months] months, oldest
  /// first, paired with a short label.
  List<MapEntry<String, int>> monthlyVisits(DateTime now, {int months = 6}) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    final buckets = <String, int>{};
    final keys = <String>[];
    for (var i = months - 1; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i);
      final key = '${names[m.month - 1]} ${m.year % 100}';
      keys.add(key);
      buckets[key] = 0;
    }

    for (final v in visits) {
      final d = v.evaluationDate;
      final key = '${names[d.month - 1]} ${d.year % 100}';
      if (buckets.containsKey(key)) buckets[key] = buckets[key]! + 1;
    }

    return keys.map((k) => MapEntry(k, buckets[k]!)).toList();
  }

  /// Farms this officer has evaluated, with their visit counts, most first.
  List<MapEntry<String, int>> get farmsCovered {
    final counts = <String, int>{};
    for (final v in visits) {
      final name = v.farmName.isEmpty ? '—' : v.farmName;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    final rows = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return rows;
  }

  /// Newest first.
  List<Evaluation> recentVisits({int limit = 8}) =>
      visits.reversed.take(limit).toList();

  /// Build one per account.
  ///
  /// Driven by the user list rather than by evaluations, so an officer with
  /// an account and no submitted work still appears — that is exactly the
  /// person a supervisor needs to spot.
  static List<OfficerStats> buildAll(FleetData data) {
    final byEo = <String, List<Evaluation>>{};
    for (final v in data.evaluations) {
      byEo.putIfAbsent(v.eoId, () => []).add(v);
    }

    final registered = <String, int>{};
    for (final Farm f in data.farms) {
      registered[f.createdBy] = (registered[f.createdBy] ?? 0) + 1;
    }

    final rows = data.users
        .map((u) => OfficerStats(
              user: u,
              visits: byEo[u.uid] ?? const [],
              farmsRegistered: registered[u.uid] ?? 0,
            ))
        .toList();

    rows.sort((a, b) => b.visitCount.compareTo(a.visitCount));
    return rows;
  }
}