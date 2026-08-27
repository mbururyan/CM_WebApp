import 'package:cloud_firestore/cloud_firestore.dart';

import 'session_service.dart';

/// A delete that was refused for a reason the user needs to see.
class AdminFailure implements Exception {
  const AdminFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// One row of the append-only deletions log.
class DeletionEntry {
  const DeletionEntry({
    required this.id,
    required this.collection,
    required this.docId,
    required this.summary,
    required this.reason,
    required this.deletedByName,
    required this.deletedAt,
  });

  final String id;
  final String collection;
  final String docId;
  final String summary;
  final String reason;
  final String deletedByName;
  final DateTime? deletedAt;

  factory DeletionEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return DeletionEntry(
      id: doc.id,
      collection: (d['collection'] as String?) ?? '',
      docId: (d['doc_id'] as String?) ?? '',
      summary: (d['summary'] as String?) ?? '',
      reason: (d['reason'] as String?) ?? '',
      deletedByName: (d['deleted_by_name'] as String?) ?? '—',
      deletedAt: (d['deleted_at'] as Timestamp?)?.toDate(),
    );
  }
}

/// Admin writes: deletes, and the log that records them.
///
/// Every delete is a hard delete — the document is gone — but a full copy
/// is written to `deletions` in the same batch. On the Spark plan there are
/// no backups, so this log is the only way back.
class AdminService {
  AdminService._();

  static final _db = FirebaseFirestore.instance;

  /// Delete one submitted visit.
  static Future<void> deleteEvaluation({
    required String evalId,
    required String summary,
    String reason = '',
  }) async {
    await _deleteWithLog(
      collection: 'evaluations',
      docId: evalId,
      summary: summary,
      reason: reason,
    );
  }

  /// Delete a farm, but only when nothing points at it.
  ///
  /// A farm with visits cannot go: every evaluation carries `farm_id`, and
  /// removing the parent would leave rows that join to nothing — the export
  /// and the Power BI reports would break quietly rather than loudly.
  static Future<void> deleteFarm({
    required String farmId,
    required String summary,
    String reason = '',
  }) async {
    final linked = await _db
        .collection('evaluations')
        .where('farm_id', isEqualTo: farmId)
        .limit(1)
        .get();

    if (linked.docs.isNotEmpty) {
      throw const AdminFailure(
        'This farm still has visits attached. Delete those first, or keep '
        'the farm — its visits would otherwise be left pointing at nothing.',
      );
    }

    await _deleteWithLog(
      collection: 'farms',
      docId: farmId,
      summary: summary,
      reason: reason,
    );
  }

  /// Reads the document, then writes the log entry and deletes the original
  /// in a single batch.
  ///
  /// The batch is what makes this safe: both operations land or neither
  /// does, so there is never a deleted document with no record of it.
  static Future<void> _deleteWithLog({
    required String collection,
    required String docId,
    required String summary,
    required String reason,
  }) async {
    final user = SessionService.maybeUser;
    if (user == null || !user.isAdmin) {
      throw const AdminFailure('Only admins can delete records.');
    }

    final ref = _db.collection(collection).doc(docId);

    late final DocumentSnapshot<Map<String, dynamic>> snap;
    try {
      snap = await ref.get();
    } on FirebaseException catch (e) {
      throw AdminFailure('Could not read the record (${e.code}).');
    }

    if (!snap.exists) {
      throw const AdminFailure(
          'That record is already gone — someone may have deleted it.');
    }

    final batch = _db.batch();

    batch.set(_db.collection('deletions').doc(), {
      'collection': collection,
      'doc_id': docId,
      'summary': summary,
      'reason': reason.trim(),
      'deleted_by': user.uid,
      'deleted_by_name': user.displayName,
      'deleted_at': FieldValue.serverTimestamp(),
      // The whole original document. Verbose on purpose — this is the copy
      // you would rebuild from.
      'payload': snap.data(),
    });

    batch.delete(ref);

    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const AdminFailure(
            'The database refused this delete. Check that your account still '
            'has the admin role.');
      }
      throw AdminFailure('Delete failed (${e.code}).');
    }
  }

  /// The log, newest first. Admin-only by rule.
  static Future<List<DeletionEntry>> deletionLog({int limit = 50}) async {
    final snap = await _db
        .collection('deletions')
        .orderBy('deleted_at', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => DeletionEntry.fromDoc(d)).toList();
  }
}