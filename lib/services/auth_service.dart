import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

/// A sign-in problem we can show the user verbatim.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService._();

  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  static Stream<User?> get authState => _auth.authStateChanges();

  static User? get currentUser => _auth.currentUser;

  /// Sign in with the same username and password used on the phone.
  ///
  /// Firebase Auth only knows about emails, so the username is resolved
  /// through `usernames/{username}` first — a document readable without
  /// being signed in, which is the whole reason that collection exists.
  static Future<void> signIn({
    required String username,
    required String password,
  }) async {
    final key = username.trim().toLowerCase();
    if (key.isEmpty) throw const AuthFailure('Enter your username.');

    late final DocumentSnapshot<Map<String, dynamic>> lookup;
    try {
      lookup = await _db.collection('usernames').doc(key).get();
    } on FirebaseException catch (e) {
      throw AuthFailure(_firestoreMessage(e));
    }

    if (!lookup.exists) {
      throw const AuthFailure('No account found with that username.');
    }

    final email = lookup.data()?['email'] as String?;
    if (email == null || email.isEmpty) {
      throw const AuthFailure(
          'That account has no email on file. Ask an admin to check it.');
    }

    try {
      await _auth.signInWithEmailAndPassword(
          email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_authMessage(e));
    }
  }

  /// Load `users/{uid}`. Throws if the profile is missing — an auth account
  /// with no profile document can't be given a role, so it can't be let in.
  static Future<AppUser> loadProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) {
        throw const AuthFailure(
            'Your account has no profile record. Ask an admin to set it up.');
      }
      return AppUser.fromDoc(doc);
    } on FirebaseException catch (e) {
      throw AuthFailure(_firestoreMessage(e));
    }
  }

  static Future<void> signOut() => _auth.signOut();

  static String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      // Newer Firebase collapses wrong-password and user-not-found into this
      // one code on purpose, so an attacker can't probe for valid accounts.
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'That password is not right. Try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a minute and try again.';
      case 'network-request-failed':
        return 'No connection. Check your network and try again.';
      default:
        return 'Sign-in failed (${e.code}).';
    }
  }

  static String _firestoreMessage(FirebaseException e) {
    if (e.code == 'permission-denied') {
      return 'This account is not allowed to read that record.';
    }
    if (e.code == 'unavailable') {
      return 'Cannot reach the database. Check your connection.';
    }
    return 'Database error (${e.code}).';
  }
}