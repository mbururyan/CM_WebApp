import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/farm.dart';
import 'session_service.dart';

class FarmAdminFailure implements Exception {
  const FarmAdminFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Editing farm records. Admins may correct any farm; the registering
/// officer may correct their own. `created_by` is never editable — the rules
/// reject a write that moves it, and provenance has to stay answerable.
class FarmAdminService {
  FarmAdminService._();

  static final _db = FirebaseFirestore.instance;

  static const productionSystems = <String>[
    'feedlot',
    'intensive',
    'semi_intensive',
    'extensive',
  ];

  static Future<void> update({
    required Farm farm,
    required String name,
    required String ownerManager,
    required String contactPhone,
    required String contactEmail,
    required String county,
    required String subCounty,
    required String locationArea,
    required String productionSystem,
  }) async {
    final me = SessionService.maybeUser;
    if (me == null) throw const FarmAdminFailure('Not signed in.');
    if (!me.isAdmin && farm.createdBy != me.uid) {
      throw const FarmAdminFailure(
          'You can only edit farms you registered yourself.');
    }
    if (name.trim().isEmpty) {
      throw const FarmAdminFailure('Farm name cannot be blank.');
    }
    if (county.trim().isEmpty) {
      throw const FarmAdminFailure('County cannot be blank.');
    }
    // Mandatory on the mobile app now, so keep the two in step rather than
    // letting the web quietly allow a blank the phone would reject.
    if (locationArea.trim().isEmpty) {
      throw const FarmAdminFailure('Village cannot be blank.');
    }

    try {
      await _db.collection('farms').doc(farm.id).update({
        'name': name.trim(),
        'owner_manager': ownerManager.trim(),
        'contact_phone': contactPhone.trim(),
        'contact_email': contactEmail.trim(),
        'county': county.trim(),
        'sub_county': subCounty.trim(),
        'location_area': locationArea.trim(),
        'production_system': productionSystem,
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': me.uid,
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const FarmAdminFailure(
            'The database refused this edit. Check your account still has '
            'the admin role.');
      }
      throw FarmAdminFailure('Could not save (${e.code}).');
    }
  }

  static Future<List<Farm>> listFarms() async {
    final snap = await _db.collection('farms').get();
    final rows = snap.docs.map((d) => Farm.fromDoc(d)).toList()
      ..sort((a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return rows;
  }
}