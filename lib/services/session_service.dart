import '../models/app_user.dart';

/// The signed-in profile, held in memory for the life of the tab.
///
/// Same idea as the mobile app's SessionService: read `users/{uid}` once at
/// sign-in instead of from every widget that needs a name or a role. On the
/// web a page refresh clears this, and AuthGate reloads it — which is fine,
/// it's one document read.
class SessionService {
  SessionService._();

  static AppUser? _current;

  /// The signed-in user. Only call from inside the signed-in tree, where
  /// AuthGate has already guaranteed a profile exists.
  static AppUser get user => _current!;

  static AppUser? get maybeUser => _current;

  static bool get isSignedIn => _current != null;

  /// The single source of truth for permission checks in the UI.
  /// Rules enforce the same thing server-side — this only hides controls.
  static bool get isAdmin => _current?.isAdmin ?? false;

  static void set(AppUser user) => _current = user;

  static void clear() => _current = null;
}