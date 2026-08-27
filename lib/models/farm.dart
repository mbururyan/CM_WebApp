import 'package:cloud_firestore/cloud_firestore.dart';

/// A row from `farms/{farmId}`. Field names match the mobile app exactly.
class Farm {
  const Farm({
    required this.id,
    required this.name,
    required this.county,
    required this.subCounty,
    required this.locationArea,
    required this.ownerManager,
    required this.contactPhone,
    required this.productionSystem,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String county;
  final String subCounty;
  final String locationArea;
  final String ownerManager;
  final String contactPhone;
  final String productionSystem;

  /// Provenance — the EO who registered it. NOT ownership of the data.
  final String createdBy;

  /// Denormalised, and absent on early pilot docs. Falls back to a dash so
  /// no table cell ever renders "null".
  final String createdByName;

  final DateTime? createdAt;

  factory Farm.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Farm(
      id: doc.id,
      name: (d['name'] as String?)?.trim() ?? 'Unnamed farm',
      county: (d['county'] as String?) ?? '',
      subCounty: (d['sub_county'] as String?) ?? '',
      locationArea: (d['location_area'] as String?) ?? '',
      ownerManager: (d['owner_manager'] as String?) ?? '',
      contactPhone: (d['contact_phone'] as String?) ?? '',
      productionSystem: (d['production_system'] as String?) ?? '',
      createdBy: (d['created_by'] as String?) ?? '',
      createdByName: (d['created_by_name'] as String?)?.trim().isNotEmpty ==
              true
          ? (d['created_by_name'] as String).trim()
          : '—',
      createdAt: (d['created_at'] as Timestamp?)?.toDate(),
    );
  }

  /// `semi_intensive` -> `Semi intensive`, for display.
  String get systemLabel {
    if (productionSystem.isEmpty) return '—';
    final words = productionSystem.replaceAll('_', ' ');
    return words[0].toUpperCase() + words.substring(1);
  }
}