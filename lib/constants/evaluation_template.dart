import '../models/evaluation.dart';

/// The question catalogue behind every stored answer id.
///
/// Ported from the mobile app's `constants/evaluation_template.dart`.
/// The web app never asks these questions — it only has to be able to say
/// what was asked, so that a stored `feed_plan: true` can be printed back
/// as a sentence a farmer can read.
///
/// KEEP IN STEP WITH MOBILE. Question text may be edited freely on either
/// side, but the ids are the contract: change one and existing reports
/// stop being able to describe themselves.
///
/// One deliberate difference from the mobile file: mobile keys sections
/// with a `SectionKey` enum, the web app with the string keys in
/// [Sections]. Same sections, and the strings are what Firestore stores.
class ChecklistQuestion {
  const ChecklistQuestion(this.id, this.text);
  final String id;
  final String text;
}

/// Everything that makes one checklist section different from another.
class SectionTemplate {
  const SectionTemplate({
    required this.key,
    required this.questions,
    this.positiveLabel = 'Yes',
    this.negativeLabel = 'No',
  });

  /// A key from [Sections.keys].
  final String key;

  final List<ChecklistQuestion> questions;
  final String positiveLabel;
  final String negativeLabel;
}

class EvaluationTemplate {
  EvaluationTemplate._();

  static const feeding = SectionTemplate(
    key: 'feeding',
    questions: [
      ChecklistQuestion('feed_plan', 'Documented feeding plan in place'),
      ChecklistQuestion('ration_stage', 'Ration matches production stage'),
      ChecklistQuestion('minerals', 'Minerals and salt licks provided'),
      ChecklistQuestion('water', 'Clean water always available'),
      ChecklistQuestion('dry_season', 'Dry season feeding strategy in place'),
    ],
  );

  static const feedQuality = SectionTemplate(
    key: 'feed_quality',
    positiveLabel: 'Adequate',
    negativeLabel: 'Inadequate',
    questions: [
      ChecklistQuestion('forage', 'Forage quality'),
      ChecklistQuestion('concentrate', 'Concentrate quality'),
      ChecklistQuestion('storage', 'Feed storage conditions'),
      ChecklistQuestion('hygiene', 'Feed hygiene and spoilage control'),
      ChecklistQuestion('consistency', 'Consistency of feed supply'),
    ],
  );

  static const biosecurity = SectionTemplate(
    key: 'biosecurity',
    questions: [
      ChecklistQuestion('access', 'Farm access is restricted'),
      ChecklistQuestion('footbath', 'Footbath or visitor record in use'),
      ChecklistQuestion('quarantine', 'New animals are quarantined'),
      ChecklistQuestion('deworming', 'Routine deworming programme'),
      ChecklistQuestion('isolation', 'Sick animals are isolated promptly'),
    ],
  );

  static const housing = SectionTemplate(
    key: 'housing',
    questions: [
      ChecklistQuestion('space', 'Adequate space per animal'),
      ChecklistQuestion('bedding', 'Clean, dry bedding or flooring'),
      ChecklistQuestion('ventilation', 'Ventilation is adequate'),
      ChecklistQuestion('shade', 'Shade and weather protection provided'),
      ChecklistQuestion('handling', 'Handling facilities are safe and usable'),
    ],
  );

  /// Five yes/no practices, so the section counts itself out of 5.
  ///
  /// `ear_tags` was added after the first v2 visits were recorded, so it
  /// is ABSENT rather than false on those. Readers must check for the key
  /// rather than assume a missing answer means no.
  static const performanceChecks = [
    ChecklistQuestion(
        'ear_tags', 'Animals individually identified (ear tags / RFID)'),
    ChecklistQuestion('scale', 'Weighing scale available'),
    ChecklistQuestion('schedule', 'Regular weighing schedule kept'),
    ChecklistQuestion('adg_calc', 'Average daily gain is calculated'),
    ChecklistQuestion('perf_records', 'Performance records are maintained'),
  ];

  /// id -> (label, unit). Measured, not scored. A farm that does not weigh
  /// cannot report a weight, and a blank is more honest than a guess.
  static const performanceKpis = <String, List<String>>{
    'weaning_weight': ['Weaning weight', 'kg'],
    'adg': ['Average daily gain', 'kg/day'],
    'slaughter_weight': ['Slaughter weight', 'kg'],
    'mortality_pct': ['Mortality rate', '%'],
  };

  static const recordTypes = [
    ChecklistQuestion('breeding', 'Breeding records'),
    ChecklistQuestion('health', 'Health and treatment records'),
    ChecklistQuestion('feed', 'Feed records'),
    ChecklistQuestion('financial', 'Financial records'),
    ChecklistQuestion('mortality', 'Mortality records'),
  ];

  /// Every v2 visit records these three. A blank would be
  /// indistinguishable from "not done", and FCL needs the difference.
  static const mandatoryVaccinations = [
    'FMD',
    'LSD',
    'Black quarter / anthrax',
  ];

  /// Recorded when known. Omitted from the array entirely when the officer
  /// could not establish it, which is a third state — not "not covered".
  static const optionalVaccinations = ['Brucellosis'];

  static const defaultVaccinations = [
    ...mandatoryVaccinations,
    ...optionalVaccinations,
  ];

  /// Stored value -> label. `not_done` and `unknown` are real answers, not
  /// missing data.
  static const vaccinationFrequencies = <String, String>{
    'annually': 'Annually',
    'biannually': 'Twice a year',
    'on_arrival': 'On arrival only',
    'rarely': 'Rarely',
    'not_done': 'Not done',
    'unknown': 'Farmer unsure',
  };

  /// The four sections that share the checklist shape. Vaccination,
  /// performance and records are rendered by their own code.
  static SectionTemplate? forKey(String key) {
    switch (key) {
      case 'feeding':
        return feeding;
      case 'feed_quality':
        return feedQuality;
      case 'biosecurity':
        return biosecurity;
      case 'housing':
        return housing;
      default:
        return null;
    }
  }
}