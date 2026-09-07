import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/config_service.dart';

/// The seven sections, in the order the mobile app displays them.
/// Keys are permanent; only the labels may change.
class Sections {
  Sections._();

  static const keys = <String>[
    'feeding',
    'feed_quality',
    'biosecurity',
    'vaccination',
    'housing',
    'performance',
    'records',
  ];

  static const labels = <String, String>{
    'feeding': 'Feeding and nutrition',
    'feed_quality': 'Feed quality',
    'biosecurity': 'Biosecurity and disease control',
    'vaccination': 'Vaccination',
    'housing': 'Housing and welfare',
    'performance': 'Performance monitoring',
    'records': 'Record keeping',
  };

  static String label(String key) => labels[key] ?? key;
}

/// One section's stored result.
class SectionResult {
  const SectionResult({
    required this.score,
    required this.answers,
    required this.comment,
  });

  final int score;

  /// Answer id -> value. Mostly bool; the performance section also carries
  /// optional numeric KPIs which are absent (never 0) when unknown.
  final Map<String, dynamic> answers;

  /// The EO's internal field note. Never farmer-facing — it must not reach
  /// the PDF. It is fine on this dashboard, which is management-only.
  final String comment;
}

/// One disease row from the `vaccinations` array.
class Vaccination {
  const Vaccination({
    required this.disease,
    required this.frequency,
    required this.lastAdministered,
    required this.dateUnknown,
    required this.recordsAvailable,
  });

  final String disease;
  final String frequency;
  final DateTime? lastAdministered;

  /// An honest "the farmer cannot recall", as opposed to a guessed date.
  final bool dateUnknown;

  final bool recordsAvailable;

  factory Vaccination.fromMap(Map<String, dynamic> m) => Vaccination(
        disease: (m['disease'] as String?) ?? '—',
        frequency: (m['frequency'] as String?) ?? 'unknown',
        lastAdministered: (m['last_administered'] as Timestamp?)?.toDate(),
        dateUnknown: (m['date_unknown'] as bool?) ?? false,
        recordsAvailable: (m['records_available'] as bool?) ?? false,
      );
}

/// One photograph attached to a visit.
///
/// Evidence for the office, not for the farmer — these never reach the
/// PDF. Changing that would be a deliberate decision, not a default.
class EvaluationPhoto {
  const EvaluationPhoto({
    required this.id,
    required this.filename,
    required this.url,
    required this.caption,
    required this.bytes,
    required this.addedAt,
  });

  final String id;
  final String filename;

  /// Storage download url, or null while the photo is still queued on the
  /// officer's phone. A null url is NOT a missing photo.
  final String? url;

  /// Reserved. Always empty for now.
  final String caption;

  final int bytes;

  /// Device clock, not the server — serverTimestamp() is not allowed
  /// inside an array element. Fine for ordering within a visit, not for
  /// anything else.
  final DateTime? addedAt;

  /// Taken, but not yet uploaded. Show it as waiting, never as broken.
  bool get isQueued => url == null || url!.isEmpty;

  factory EvaluationPhoto.fromMap(Map<String, dynamic> m) {
    final raw = (m['url'] as String?)?.trim();
    return EvaluationPhoto(
      id: (m['id'] as String?) ?? '',
      filename: (m['filename'] as String?) ?? '',
      url: (raw == null || raw.isEmpty) ? null : raw,
      caption: (m['caption'] as String?)?.trim() ?? '',
      bytes: (m['bytes'] as num?)?.toInt() ?? 0,
      addedAt: (m['added_at'] as Timestamp?)?.toDate(),
    );
  }
}

/// A row from `evaluations/{evalId}` — one farm visit.
class Evaluation {
  const Evaluation({
    required this.id,
    required this.farmId,
    required this.farmName,
    required this.county,
    required this.subCounty,
    required this.eoId,
    required this.eoName,
    required this.evaluationDate,
    required this.breedingCows,
    required this.bulls,
    required this.calves,
    required this.growersSteers,
    required this.sections,
    required this.vaccinations,
    required this.keyStrengths,
    required this.areasImprovement,
    required this.recommendations,
    required this.totalScore,
    required this.rating,
    required this.status,
    required this.createdAt,
    required this.scoringVersion,
    required this.photos,
  });

  final String id;
  final String farmId;
  final String farmName;
  final String county;
  final String subCounty;
  final String eoId;
  final String eoName;

  /// User-picked date of the visit. This is what analytics group by.
  final DateTime evaluationDate;

  final int breedingCows;
  final int bulls;
  final int calves;
  final int growersSteers;

  /// Section key -> result. Only sections actually present are included, so
  /// a part-finished visit contributes what it has and nothing more.
  final Map<String, SectionResult> sections;

  final List<Vaccination> vaccinations;
  final List<String> keyStrengths;
  final List<String> areasImprovement;

  /// The only free text intended for the farmer.
  final String recommendations;

  final int totalScore;
  final String rating;
  final String status;

  /// Which scoring scheme produced [totalScore].
  ///
  /// v1 took a 1-5 judgement per section, so a visit ran 7-35 and a
  /// section score of 3 was an opinion. v2 has the sections count
  /// themselves, one point per item present, so 0 is reachable and a 3
  /// means three yes answers. The two are NOT the same measurement and
  /// must never be averaged together.
  ///
  /// Pilot documents predate the field. Absent means 1.
  final int scoringVersion;

  /// Server write time. Used only to break same-day ties.
  final DateTime? createdAt;

  /// Up to ten per visit. Unscored and outside the seven sections — a
  /// visit with no photos is still complete.
  final List<EvaluationPhoto> photos;

  factory Evaluation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};

    final rawSections = (d['sections'] as Map<String, dynamic>?) ?? const {};
    final sections = <String, SectionResult>{};
    for (final key in Sections.keys) {
      final s = rawSections[key];
      if (s is! Map) continue;
      final score = s['score'];
      sections[key] = SectionResult(
        score: score is num ? score.toInt() : 0,
        answers: Map<String, dynamic>.from(
            (s['answers'] as Map?) ?? const <String, dynamic>{}),
        comment: (s['comment'] as String?)?.trim() ?? '',
      );
    }

    return Evaluation(
      id: doc.id,
      farmId: (d['farm_id'] as String?) ?? '',
      farmName: (d['farm_name'] as String?)?.trim() ?? 'Unknown farm',
      county: (d['county'] as String?) ?? '',
      subCounty: (d['sub_county'] as String?) ?? '',
      eoId: (d['eo_id'] as String?) ?? '',
      eoName: (d['eo_name'] as String?)?.trim().isNotEmpty == true
          ? (d['eo_name'] as String).trim()
          : '—',
      // A visit with no date can't be placed on a timeline. Falling back to
      // created_at keeps it visible instead of silently dropping it.
      evaluationDate: (d['evaluation_date'] as Timestamp?)?.toDate() ??
          (d['created_at'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      breedingCows: _int(d['breeding_cows']),
      bulls: _int(d['bulls']),
      calves: _int(d['calves']),
      growersSteers: _int(d['growers_steers']),
      sections: sections,
      vaccinations: ((d['vaccinations'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => Vaccination.fromMap(Map<String, dynamic>.from(m)))
          .toList(),
      keyStrengths: _strings(d['key_strengths']),
      areasImprovement: _strings(d['areas_improvement']),
      recommendations: (d['recommendations'] as String?)?.trim() ?? '',
      totalScore: _int(d['total_score']),
      rating: (d['rating'] as String?) ?? '',
      status: (d['status'] as String?) ?? 'draft',
      createdAt: (d['created_at'] as Timestamp?)?.toDate(),
      scoringVersion: (d['scoring_version'] as num?)?.toInt() ?? 1,
      photos: ((d['photos'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => EvaluationPhoto.fromMap(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }

  static int _int(dynamic v) => v is num ? v.toInt() : 0;

  static List<String> _strings(dynamic v) => ((v as List?) ?? const [])
      .whereType<String>()
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  /// Section key -> score, for the analytics layer.
  Map<String, int> get sectionScores =>
      sections.map((k, v) => MapEntry(k, v.score));

  /// Computed, never stored — same rule as the mobile app.
  int get totalHerd => breedingCows + bulls + calves + growersSteers;

  bool get isSubmitted => status == 'submitted';

  /// Whether this visit's scores can be compared with current ones.
  bool get isCurrentScoring => scoringVersion >= 2;

  bool get hasPhotos => photos.isNotEmpty;

  /// Only the ones that have reached Storage and can actually be shown.
  List<EvaluationPhoto> get visiblePhotos =>
      photos.where((p) => !p.isQueued).toList();

  int get queuedPhotoCount => photos.where((p) => p.isQueued).length;

  /// Rating derived from the score rather than read from the document, so
  /// changing the bands in Settings re-bands history without a migration.
  static String bandFor(int total) => ConfigService.current.bandFor(total);

  /// Always recomputed, never the stored `rating` field. The stored value
  /// was banded with whatever thresholds were live when the visit was
  /// submitted; recomputing keeps every score on one consistent scale.
  String get band => bandFor(totalScore);

  String get ratingLabel {
    final r = band;
    return r.isEmpty ? '—' : r[0].toUpperCase() + r.substring(1);
  }
}