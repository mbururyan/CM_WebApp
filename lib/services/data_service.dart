import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/evaluation.dart';
import '../models/farm.dart';

/// Everything the dashboard needs, fetched once.
class FleetData {
  const FleetData({
    required this.farms,
    required this.evaluations,
    this.users = const [],
  });

  final List<Farm> farms;

  /// Submitted visits only. Drafts are an officer's unfinished work and
  /// would drag every average down if counted.
  final List<Evaluation> evaluations;

  /// Every account. Loaded separately because an officer with no visits
  /// would be invisible if the list were derived from evaluations.
  final List<AppUser> users;

  bool get isEmpty => farms.isEmpty && evaluations.isEmpty;
}

/// Loads the whole dataset and hands it to the analytics layer to slice in
/// memory.
///
/// This is a deliberate choice for the scale involved (~50 farms, tens of
/// visits): no composite indexes, no per-filter round trips, and filters
/// that respond instantly. It would be the wrong choice at tens of
/// thousands of documents — at that point filtering moves back to queries.
class DataService {
  DataService._();

  static final _db = FirebaseFirestore.instance;

  /// [withUsers] is off by default so the pages that don't need accounts
  /// don't pay for a third query on every load.
  static Future<FleetData> loadAll({bool withUsers = false}) async {
    final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[
      _db.collection('farms').get(),
      // No orderBy: an index-free query is one less thing to configure, and
      // sorting a few dozen rows in Dart costs nothing.
      _db
          .collection('evaluations')
          .where('status', isEqualTo: 'submitted')
          .get(),
      if (withUsers) _db.collection('users').get(),
    ];

    final results = await Future.wait(futures);

    return FleetData(
      farms: results[0].docs.map((d) => Farm.fromDoc(d)).toList(),
      evaluations: results[1].docs.map((d) => Evaluation.fromDoc(d)).toList(),
      users: withUsers
          ? results[2].docs.map((d) => AppUser.fromDoc(d)).toList()
          : const [],
    );
  }
}