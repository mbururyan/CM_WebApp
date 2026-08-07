import 'package:cloud_firestore/cloud_firestore.dart';

/// A row from `users/{uid}`. Field names match the mobile app exactly —
/// mobile is canonical, so if it changes there, copy it here.
class AppUser {
  const AppUser({
    required this.uid,
    required this.fullName,
    required this.username,
    required this.email,
    required this.phone,
    required this.role,
    required this.active,
  });

  final String uid;
  final String fullName;
  final String username;
  final String email;
  final String phone;
  final String role;
  final bool active;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return AppUser(
      uid: doc.id,
      fullName: (d['full_name'] as String?)?.trim() ?? '',
      username: (d['username'] as String?) ?? '',
      email: (d['email'] as String?) ?? '',
      phone: (d['phone'] as String?) ?? '',
      role: (d['role'] as String?) ?? 'evaluator',
      // Older docs may predate the field; treat a missing value as active
      // rather than locking someone out.
      active: (d['active'] as bool?) ?? true,
    );
  }

  bool get isAdmin => role == 'admin';

  String get roleLabel => role.isEmpty ? 'USER' : role.toUpperCase();

  /// Initials for the sidebar avatar. Falls back to the username so this
  /// never renders empty, including on early docs with no full_name.
  String get initials {
    final source = fullName.isNotEmpty ? fullName : username;
    if (source.isEmpty) return '?';
    final parts =
        source.split(RegExp(r'[\s.]+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  /// What the sidebar shows. Never blank.
  String get displayName => fullName.isNotEmpty ? fullName : username;
}