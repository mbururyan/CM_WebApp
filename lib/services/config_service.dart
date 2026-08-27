import 'package:cloud_firestore/cloud_firestore.dart';

/// Dashboard-wide settings, held in `config/dashboard`.
///
/// The rating bands live here rather than in code so that when FCL finally
/// confirms them, changing them re-bands every score already recorded — no
/// migration, no rewrite of history. Scores stay raw; banding happens on
/// read.
class AppConfig {
  const AppConfig({
    this.excellentMin = 30,
    this.goodMin = 24,
    this.fairMin = 17,
    this.overdueDays = 90,
  });

  final int excellentMin;
  final int goodMin;
  final int fairMin;

  /// A farm counts as overdue when its newest visit is older than this.
  final int overdueDays;

  /// The band a total score falls in. Anything below [fairMin] is poor.
  String bandFor(int total) {
    if (total >= excellentMin) return 'excellent';
    if (total >= goodMin) return 'good';
    if (total >= fairMin) return 'fair';
    return 'poor';
  }

  factory AppConfig.fromMap(Map<String, dynamic>? d) {
    if (d == null) return const AppConfig();
    int pick(String key, int fallback) {
      final v = d[key];
      return v is num ? v.toInt() : fallback;
    }

    return AppConfig(
      excellentMin: pick('excellent_min', 30),
      goodMin: pick('good_min', 24),
      fairMin: pick('fair_min', 17),
      overdueDays: pick('overdue_days', 90),
    );
  }

  Map<String, dynamic> toMap() => {
        'excellent_min': excellentMin,
        'good_min': goodMin,
        'fair_min': fairMin,
        'overdue_days': overdueDays,
      };

  AppConfig copyWith({
    int? excellentMin,
    int? goodMin,
    int? fairMin,
    int? overdueDays,
  }) =>
      AppConfig(
        excellentMin: excellentMin ?? this.excellentMin,
        goodMin: goodMin ?? this.goodMin,
        fairMin: fairMin ?? this.fairMin,
        overdueDays: overdueDays ?? this.overdueDays,
      );

  /// Bands must descend and stay inside 1–35, or scores land in no band at
  /// all. Returns the problem, or null when the values are usable.
  String? validate() {
    if (excellentMin > 35) return 'Excellent cannot start above 35.';
    if (excellentMin <= goodMin) {
      return 'Excellent must start above where Good starts.';
    }
    if (goodMin <= fairMin) return 'Good must start above where Fair starts.';
    if (fairMin < 1) return 'Fair must start at 1 or higher.';
    if (overdueDays < 7) return 'Overdue threshold must be at least 7 days.';
    return null;
  }
}

class ConfigService {
  ConfigService._();

  static final _db = FirebaseFirestore.instance;
  static const _path = 'config/dashboard';

  /// The live config. Defaults are the provisional bands from the mobile
  /// app, so the dashboard works correctly before the document exists.
  static AppConfig current = const AppConfig();

  static Future<AppConfig> load() async {
    try {
      final doc = await _db.doc(_path).get();
      current = AppConfig.fromMap(doc.data());
    } catch (_) {
      // A config read failing must never block sign-in — the defaults are
      // correct, just not customised.
      current = const AppConfig();
    }
    return current;
  }

  static Future<void> save(AppConfig config) async {
    final problem = config.validate();
    if (problem != null) throw Exception(problem);

    await _db.doc(_path).set(config.toMap(), SetOptions(merge: true));
    current = config;
  }
}