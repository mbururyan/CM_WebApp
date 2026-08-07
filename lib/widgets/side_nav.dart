import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'brand_mark.dart';

/// One destination in the sidebar.
class NavItem {
  const NavItem({
    required this.label,
    required this.icon,
    required this.subtitle,
    this.section,
    this.adminOnly = false,
  });

  final String label;
  final IconData icon;

  /// Shown under the page title in the top bar.
  final String subtitle;

  /// When set, a small section label is drawn above this item.
  final String? section;

  /// Hidden from evaluators. Reads are open to everyone; these are the
  /// destinations that only exist to write or extract.
  final bool adminOnly;
}

/// The app's table of contents. Index into this list IS the page index —
/// filtering for role never renumbers anything, it just skips rows.
const navItems = <NavItem>[
  NavItem(
    label: 'Overview',
    icon: Icons.space_dashboard_outlined,
    subtitle: 'Beef division · all counties · last 30 days',
  ),
  NavItem(
    label: 'Visits',
    icon: Icons.event_note_outlined,
    subtitle: 'Every submitted evaluation',
  ),
  NavItem(
    label: 'Farms',
    icon: Icons.home_work_outlined,
    subtitle: 'The farm register',
  ),
  NavItem(
    label: 'Evaluators',
    icon: Icons.groups_outlined,
    subtitle: 'Field officers and their activity',
  ),
  NavItem(
    label: 'Exports',
    icon: Icons.file_download_outlined,
    subtitle: 'Generated in the browser, no server',
    section: 'Admin',
    adminOnly: true,
  ),
  NavItem(
    label: 'Settings',
    icon: Icons.tune_outlined,
    subtitle: 'Scoring and thresholds',
    adminOnly: true,
  ),
];

class SideNav extends StatelessWidget {
  const SideNav({
    super.key,
    required this.user,
    required this.selectedIndex,
    required this.onSelect,
    required this.onSignOut,
  });

  final AppUser user;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    // Keep the original index alongside each visible item.
    final visible = <MapEntry<int, NavItem>>[];
    for (var i = 0; i < navItems.length; i++) {
      final item = navItems[i];
      if (item.adminOnly && !user.isAdmin) continue;
      visible.add(MapEntry(i, item));
    }

    return Container(
      width: Layout.railWidth,
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            child: Row(
              children: [
                const BrandMark(size: 34, radius: 9),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CM Beef',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                    Text("Farmer's Choice", style: AppTheme.eyebrow),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: visible.length,
              itemBuilder: (context, i) {
                final index = visible[i].key;
                final item = visible[i].value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (item.section != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
                        child: Text(item.section!, style: AppTheme.eyebrow),
                      ),
                    _NavTile(
                      item: item,
                      selected: index == selectedIndex,
                      onTap: () => onSelect(index),
                    ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.fill,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  alignment: Alignment.center,
                  child: Text(user.initials,
                      style: AppTheme.mono(size: 11, color: AppColors.text2)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user.roleLabel,
                        style: AppTheme.eyebrow.copyWith(
                          color: user.isAdmin
                              ? AppColors.amber
                              : AppColors.greenLight,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onSignOut,
                  tooltip: 'Sign out',
                  icon: const Icon(Icons.logout, size: 17),
                  color: AppColors.muted,
                  hoverColor: AppColors.fill,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatefulWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final bg = selected
        ? AppColors.greenDark
        : (_hovered ? AppColors.fill : Colors.transparent);
    final fg = selected
        ? Colors.white
        : (_hovered ? AppColors.text : AppColors.text2);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(widget.item.icon, size: 18, color: fg),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    widget.item.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: fg,
                      fontWeight:
                          selected ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}