import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/side_nav.dart';
import 'evaluators_page.dart';
import 'exports_page.dart';
import 'farms_page.dart';
import 'overview_page.dart';
import 'settings_page.dart';
import 'visits_page.dart';

/// The signed-in frame. Holds the sidebar, the top bar and the current page.
class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _index = 0;

  void _select(int i, {required bool fromDrawer}) {
    setState(() => _index = i);
    if (fromDrawer) Navigator.of(context).pop();
  }

  Future<void> _signOut() async {
    // No navigation here — AuthGate listens to the auth stream and swaps
    // the login screen back in on its own.
    await AuthService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.user;
    final isWide = MediaQuery.sizeOf(context).width >= Layout.wideBreakpoint;
    final item = navItems[_index];

    return Scaffold(
      backgroundColor: AppColors.bg,
      drawer: isWide
          ? null
          : Drawer(
              width: Layout.railWidth,
              child: SideNav(
                user: user,
                selectedIndex: _index,
                onSelect: (i) => _select(i, fromDrawer: true),
                onSignOut: _signOut,
              ),
            ),
      body: Row(
        children: [
          if (isWide) ...[
            SideNav(
              user: user,
              selectedIndex: _index,
              onSelect: (i) => _select(i, fromDrawer: false),
              onSignOut: _signOut,
            ),
            const VerticalDivider(width: 1, color: AppColors.border),
          ],
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  title: item.label,
                  subtitle: item.subtitle,
                  showMenuButton: !isWide,
                  roleLabel: user.roleLabel,
                  isAdmin: user.isAdmin,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                        isWide ? 28 : 16, 24, isWide ? 28 : 16, 56),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                            maxWidth: Layout.contentMaxWidth),
                        child: _pageFor(_index),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageFor(int i) {
    switch (i) {
      case 0:
        return const OverviewPage();
      case 1:
        return const VisitsPage();
      case 2:
        return const FarmsPage();
      case 3:
        return const EvaluatorsPage();
      case 4:
        return const ExportsPage();
      default:
        return const SettingsPage();
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.showMenuButton,
    required this.roleLabel,
    required this.isAdmin,
  });

  final String title;
  final String subtitle;
  final bool showMenuButton;
  final String roleLabel;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final accent = isAdmin ? AppColors.amber : AppColors.greenLight;

    return Container(
      padding: EdgeInsets.fromLTRB(showMenuButton ? 12 : 28, 16, 20, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (showMenuButton)
            Builder(
              builder: (context) => IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu, size: 20),
                color: AppColors.text,
                tooltip: 'Open menu',
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: accent.withValues(alpha: 0.45)),
              borderRadius: BorderRadius.circular(999),
            ),
            child:
                Text(roleLabel, style: AppTheme.eyebrow.copyWith(color: accent)),
          ),
        ],
      ),
    );
  }
}