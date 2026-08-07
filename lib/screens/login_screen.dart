import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_mark.dart';

/// Sign in with the same credentials as the mobile app.
///
/// On success this does nothing — AuthService signs in, the auth stream
/// fires, and AuthGate swaps in the dashboard.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  static const _brandWidth = 360.0;
  static const _cardWidth = 392.0;
  static const _gap = 88.0;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await AuthService.signIn(
        username: _username.text,
        password: _password.text,
      );
      // No navigation here on purpose — AuthGate reacts to the auth stream.
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Something went wrong. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= Layout.wideBreakpoint;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: Center(
                  child: isWide
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: _brandWidth,
                              child: _Brand(isWide: true),
                            ),
                            const SizedBox(width: _gap),
                            SizedBox(width: _cardWidth, child: _buildCard()),
                          ],
                        )
                      : ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxWidth: _cardWidth),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _Brand(isWide: false),
                              const SizedBox(height: 32),
                              _buildCard(),
                            ],
                          ),
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _FieldLabel('Username'),
            TextFormField(
              controller: _username,
              enabled: !_busy,
              autofocus: true,
              autofillHints: const [AutofillHints.username],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'e.g. j.mwangi'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your username' : null,
            ),
            const SizedBox(height: 14),
            const _FieldLabel('Password'),
            TextFormField(
              controller: _password,
              enabled: !_busy,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Your password',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 19,
                  ),
                  color: AppColors.muted,
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter your password' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A1512),
                  border: Border.all(color: const Color(0xFF5A2B26)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 17, color: AppColors.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.orange,
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Sign in'),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.amberDark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Use the same username and password as the mobile app. '
                'Accounts are created there, not here.',
                style: TextStyle(
                    fontSize: 12, color: AppColors.amber, height: 1.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: isWide ? 80 : 56, radius: isWide ? 22 : 16),
        SizedBox(height: isWide ? 26 : 18),
        Text("FARMER'S CHOICE · CM DIVISION", style: AppTheme.eyebrow),
        const SizedBox(height: 10),
        Text(
          'CM Beef',
          style: TextStyle(
            fontSize: isWide ? 44 : 30,
            fontWeight: FontWeight.w600,
            letterSpacing: isWide ? -1.4 : -0.9,
            height: 1,
          ),
        ),
        SizedBox(height: isWide ? 14 : 10),
        Text(
          'Farm evaluation data from the field, for management.',
          style: TextStyle(
            fontSize: isWide ? 14.5 : 13.5,
            color: AppColors.text2,
            height: 1.65,
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: AppColors.text2),
      ),
    );
  }
}