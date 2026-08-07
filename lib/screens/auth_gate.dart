import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import 'dashboard_shell.dart';
import 'login_screen.dart';

/// Decides what the app shows: login, a loading state, or the dashboard.
///
/// Nothing else navigates on sign-in or sign-out. Screens just call
/// AuthService, the auth stream fires, and this rebuilds. That's why there
/// are no Navigator calls in LoginScreen any more.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authState,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _Busy(message: 'Checking your session');
        }

        final user = snapshot.data;
        if (user == null) {
          SessionService.clear();
          return const LoginScreen();
        }

        return _ProfileLoader(uid: user.uid);
      },
    );
  }
}

/// Loads `users/{uid}` before letting anyone into the shell, because the
/// whole UI branches on `role` and rendering it before the role is known
/// would flash the wrong navigation.
class _ProfileLoader extends StatefulWidget {
  const _ProfileLoader({required this.uid});

  final String uid;

  @override
  State<_ProfileLoader> createState() => _ProfileLoaderState();
}

class _ProfileLoaderState extends State<_ProfileLoader> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ProfileLoader old) {
    super.didUpdateWidget(old);
    if (old.uid != widget.uid) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await AuthService.loadProfile(widget.uid);
      if (!profile.active) {
        await AuthService.signOut();
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'This account has been deactivated. Contact an admin.';
        });
        return;
      }
      SessionService.set(profile);
      if (!mounted) return;
      setState(() => _loading = false);
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _Busy(message: 'Loading your profile');

    if (_error != null) {
      return _Problem(
        message: _error!,
        onRetry: _load,
        onSignOut: () async {
          await AuthService.signOut();
          SessionService.clear();
        },
      );
    }

    return const DashboardShell();
  }
}

class _Busy extends StatelessWidget {
  const _Busy({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.greenLight,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem({
    required this.message,
    required this.onRetry,
    required this.onSignOut,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cannot open the dashboard',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.text2, height: 1.6),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    OutlinedButton(
                        onPressed: onRetry, child: const Text('Try again')),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: onSignOut,
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.muted),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}