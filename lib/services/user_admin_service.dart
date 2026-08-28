import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import '../models/app_user.dart';
import 'session_service.dart';

class UserAdminFailure implements Exception {
  const UserAdminFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Account administration. Admin-only, enforced by rules as well as here.
class UserAdminService {
  UserAdminService._();

  static final _db = FirebaseFirestore.instance;

  static void _requireAdmin() {
    if (!SessionService.isAdmin) {
      throw const UserAdminFailure('Only admins can manage accounts.');
    }
  }

  /// Create an account without losing your own session.
  ///
  /// createUserWithEmailAndPassword signs the CURRENT user out and signs in
  /// as the new account. That is unavoidable on the default Firebase app —
  /// so the account is created on a second, temporary app instance, which is
  /// then signed out and deleted. Your session on the default app is never
  /// touched.
  static Future<String> createUser({
    required String fullName,
    required String username,
    required String email,
    required String phone,
    required String password,
    required bool isAdmin,
  }) async {
    _requireAdmin();

    final key = username.trim().toLowerCase();
    final mail = email.trim();

    if (key.isEmpty) throw const UserAdminFailure('Username is required.');
    if (key.contains(' ')) {
      throw const UserAdminFailure('Username cannot contain spaces.');
    }
    if (fullName.trim().isEmpty) {
      throw const UserAdminFailure('Full name is required.');
    }
    if (!mail.contains('@')) {
      throw const UserAdminFailure('A valid email is required.');
    }
    if (password.length < 6) {
      throw const UserAdminFailure(
          'Password must be at least 6 characters.');
    }

    // Check the username first. Not a guarantee — two admins could race —
    // but it turns the common case into a clear message instead of a
    // half-created account.
    final taken = await _db.collection('usernames').doc(key).get();
    if (taken.exists) {
      throw const UserAdminFailure('That username is already taken.');
    }

    FirebaseApp? secondary;
    String? newUid;

    try {
      secondary = await Firebase.initializeApp(
        name: 'cm-user-creator',
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final cred = await FirebaseAuth.instanceFor(app: secondary)
          .createUserWithEmailAndPassword(email: mail, password: password);
      newUid = cred.user!.uid;

      // Profile writes go through the PRIMARY app, so they carry the
      // admin's credentials and satisfy the isAdmin() rule.
      final batch = _db.batch();
      batch.set(_db.collection('users').doc(newUid), {
        'full_name': fullName.trim(),
        'username': key,
        'email': mail,
        'phone': phone.trim(),
        'role': isAdmin ? 'admin' : 'evaluator',
        'active': true,
        'created_at': FieldValue.serverTimestamp(),
        'created_by': SessionService.user.uid,
      });
      batch.set(_db.collection('usernames').doc(key), {
        'uid': newUid,
        'email': mail,
      });
      await batch.commit();

      return newUid;
    } on FirebaseAuthException catch (e) {
      throw UserAdminFailure(switch (e.code) {
        'email-already-in-use' =>
          'That email already has an account. Use another, or find the '
              'existing account in the list.',
        'invalid-email' => 'That email address is not valid.',
        'weak-password' => 'That password is too weak.',
        _ => 'Could not create the login (${e.code}).',
      });
    } on FirebaseException catch (e) {
      // The auth account exists but the profile write failed. Say so
      // plainly — the login is real and only an admin with server access
      // can remove it, so pretending nothing happened would be worse.
      if (newUid != null) {
        throw UserAdminFailure(
          'The login was created but its profile could not be saved '
          '(${e.code}). The account cannot sign in until an admin adds a '
          'profile for it in the Firebase console.',
        );
      }
      throw UserAdminFailure('Could not save the account (${e.code}).');
    } finally {
      if (secondary != null) {
        await FirebaseAuth.instanceFor(app: secondary).signOut();
        await secondary.delete();
      }
    }
  }

  /// Edit the profile fields. Username and email are not editable here —
  /// email is the actual login credential and changing it needs the Admin
  /// SDK, and the username points at it.
  static Future<void> updateProfile({
    required String uid,
    required String fullName,
    required String phone,
  }) async {
    _requireAdmin();
    if (fullName.trim().isEmpty) {
      throw const UserAdminFailure('Full name cannot be blank.');
    }
    try {
      await _db.collection('users').doc(uid).update({
        'full_name': fullName.trim(),
        'phone': phone.trim(),
      });
    } on FirebaseException catch (e) {
      throw UserAdminFailure('Could not save (${e.code}).');
    }
  }

  static Future<void> setRole({
    required String uid,
    required bool isAdmin,
  }) async {
    _requireAdmin();
    // Nobody may remove their own admin rights: it is a one-way door that
    // can only be undone from the Firebase console.
    if (uid == SessionService.user.uid && !isAdmin) {
      throw const UserAdminFailure(
          'You cannot remove your own admin role. Ask another admin.');
    }
    try {
      await _db
          .collection('users')
          .doc(uid)
          .update({'role': isAdmin ? 'admin' : 'evaluator'});
    } on FirebaseException catch (e) {
      throw UserAdminFailure('Could not change the role (${e.code}).');
    }
  }

  /// Deactivate or restore. NOT a delete.
  ///
  /// The Firebase Auth login itself can only be removed by the Admin SDK,
  /// which needs a server. Setting active:false locks the account out of
  /// both apps immediately, which is the operational effect wanted — but
  /// the credential still exists.
  static Future<void> setActive({
    required String uid,
    required bool active,
  }) async {
    _requireAdmin();
    if (uid == SessionService.user.uid && !active) {
      throw const UserAdminFailure(
          'You cannot deactivate your own account.');
    }
    try {
      await _db.collection('users').doc(uid).update({'active': active});
    } on FirebaseException catch (e) {
      throw UserAdminFailure('Could not update the account (${e.code}).');
    }
  }

  /// Send a password reset link to the account's own email address.
  ///
  /// This is as close to "reset their password" as the Spark plan allows.
  /// Choosing a new password on someone's behalf needs the Admin SDK and a
  /// server; sending a reset link does not. The consequence is that the
  /// email on the account MUST be real and reachable — a placeholder
  /// address means the account can never be recovered.
  static Future<void> sendPasswordReset(AppUser user) async {
    _requireAdmin();
    if (user.email.trim().isEmpty) {
      throw const UserAdminFailure(
          'This account has no email on file, so no reset link can be sent. '
          'It can only be recovered from the Firebase console.');
    }
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: user.email.trim());
    } on FirebaseAuthException catch (e) {
      throw UserAdminFailure(switch (e.code) {
        'user-not-found' =>
          'Firebase has no login for that email. The profile and the login '
              'may have drifted apart.',
        'invalid-email' => 'The email on this account is not valid.',
        'too-many-requests' =>
          'Too many reset requests. Wait a few minutes.',
        _ => 'Could not send the reset link (${e.code}).',
      });
    }
  }

  static Future<List<AppUser>> listUsers() async {
    final snap = await _db.collection('users').get();
    final rows = snap.docs.map((d) => AppUser.fromDoc(d)).toList()
      ..sort((a, b) => a.displayName
          .toLowerCase()
          .compareTo(b.displayName.toLowerCase()));
    return rows;
  }
}