import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/farm.dart';
import '../services/admin_service.dart';
import '../services/config_service.dart';
import '../services/farm_admin_service.dart';
import '../services/session_service.dart';
import '../services/user_admin_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/admin_dialogs.dart';
import '../widgets/panel.dart';

enum _Section { home, accounts, farms }

/// Admin-only: accounts, farm records, scoring thresholds, deletions log.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  _Section _section = _Section.home;

  @override
  Widget build(BuildContext context) {
    switch (_section) {
      case _Section.accounts:
        return _AccountsSection(
            onBack: () => setState(() => _section = _Section.home));
      case _Section.farms:
        return _FarmsSection(
            onBack: () => setState(() => _section = _Section.home));
      case _Section.home:
        return _Home(onOpen: (s) => setState(() => _section = s));
    }
  }
}

// =====================================================================
// Landing
// =====================================================================

class _Home extends StatefulWidget {
  const _Home({required this.onOpen});

  final ValueChanged<_Section> onOpen;

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  late AppConfig _draft;
  bool _saving = false;
  late Future<List<DeletionEntry>> _log;

  @override
  void initState() {
    super.initState();
    _draft = ConfigService.current;
    _log = AdminService.deletionLog();
  }

  bool get _dirty =>
      _draft.excellentMin != ConfigService.current.excellentMin ||
      _draft.goodMin != ConfigService.current.goodMin ||
      _draft.fairMin != ConfigService.current.fairMin ||
      _draft.overdueDays != ConfigService.current.overdueDays;

  Future<void> _save() async {
    final problem = _draft.validate();
    if (problem != null) return _toast(problem, bad: true);

    setState(() => _saving = true);
    try {
      await ConfigService.save(_draft);
      if (!mounted) return;
      _toast('Saved. Scores are re-banded on the next page load.');
      setState(() {});
    } catch (e) {
      if (mounted) _toast('Could not save: $e', bad: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg, {bool bad = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: bad ? const Color(0xFF2A1512) : AppColors.fill,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 760;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- the two management doors ----
        Flex(
          direction: isWide ? Axis.horizontal : Axis.vertical,
          children: [
            Expanded(
              flex: isWide ? 1 : 0,
              child: _DoorCard(
                icon: Icons.groups_outlined,
                title: 'Evaluators and admins',
                body: 'Create accounts, edit details, grant or remove admin, '
                    'and deactivate people who have left.',
                accent: AppColors.amber,
                onTap: () => widget.onOpen(_Section.accounts),
              ),
            ),
            SizedBox(width: isWide ? 14 : 0, height: isWide ? 0 : 14),
            Expanded(
              flex: isWide ? 1 : 0,
              child: _DoorCard(
                icon: Icons.home_work_outlined,
                title: 'Farm records',
                body: 'Correct farm details — name, owner, contact, location '
                    'and production system.',
                accent: AppColors.greenLight,
                onTap: () => widget.onOpen(_Section.farms),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ---- rating bands ----
        Panel(
          title: 'Rating bands',
          note: 'Scores are stored raw and banded when read, so changing '
              'these re-labels every visit already recorded. Nothing is '
              'rewritten and nothing is lost.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BandPreview(config: _draft),
              const SizedBox(height: 20),
              _NumberRow(
                label: 'Excellent starts at',
                value: _draft.excellentMin,
                min: 2,
                max: 35,
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(excellentMin: v)),
              ),
              _NumberRow(
                label: 'Good starts at',
                value: _draft.goodMin,
                min: 2,
                max: 34,
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(goodMin: v)),
              ),
              _NumberRow(
                label: 'Fair starts at',
                value: _draft.fairMin,
                min: 1,
                max: 33,
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(fairMin: v)),
              ),
              const SizedBox(height: 6),
              Text('Anything below ${_draft.fairMin} is Poor.',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ),
        const SizedBox(height: 14),

        Panel(
          title: 'Overdue threshold',
          note: 'A farm counts as needing a visit once its newest visit is '
              'older than this.',
          child: _NumberRow(
            label: 'Days without a visit',
            value: _draft.overdueDays,
            min: 7,
            max: 365,
            step: 15,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(overdueDays: v)),
          ),
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            FilledButton(
              onPressed: _dirty && !_saving ? _save : null,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save changes'),
            ),
            const SizedBox(width: 10),
            if (_dirty)
              TextButton(
                onPressed: _saving
                    ? null
                    : () => setState(() => _draft = ConfigService.current),
                style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                child: const Text('Discard'),
              ),
          ],
        ),
        const SizedBox(height: 24),

        Panel(
          title: 'Deletions log',
          note: 'Every deleted record, newest first. Append-only — nobody, '
              'including an admin, can edit or clear this.',
          child: FutureBuilder<List<DeletionEntry>>(
            future: _log,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.greenLight),
                    ),
                  ),
                );
              }
              if (snap.hasError) {
                return Text('Could not read the log. ${snap.error}',
                    style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.muted,
                        height: 1.6));
              }
              final entries = snap.data ?? const <DeletionEntry>[];
              if (entries.isEmpty) {
                return const Text('Nothing has been deleted.',
                    style:
                        TextStyle(fontSize: 12.5, color: AppColors.muted));
              }
              return Column(
                children: [
                  for (var i = 0; i < entries.length; i++)
                    _LogRow(
                        entry: entries[i],
                        isLast: i == entries.length - 1),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DoorCard extends StatefulWidget {
  const _DoorCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_DoorCard> createState() => _DoorCardState();
}

class _DoorCardState extends State<_DoorCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
                widget.accent.withValues(alpha: _hover ? 0.12 : 0.06),
                AppColors.surface),
            border: Border.all(
                color:
                    widget.accent.withValues(alpha: _hover ? 0.8 : 0.4)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(widget.icon, size: 22, color: widget.accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 5),
                    Text(widget.body,
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.text2,
                            height: 1.5)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 18,
                  color: _hover ? widget.accent : AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Accounts
// =====================================================================

class _AccountsSection extends StatefulWidget {
  const _AccountsSection({required this.onBack});
  final VoidCallback onBack;

  @override
  State<_AccountsSection> createState() => _AccountsSectionState();
}

class _AccountsSectionState extends State<_AccountsSection> {
  late Future<List<AppUser>> _future;

  @override
  void initState() {
    super.initState();
    _future = UserAdminService.listUsers();
  }

  void _reload() =>
      setState(() => _future = UserAdminService.listUsers());

  void _toast(String msg, {bool bad = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: bad ? const Color(0xFF2A1512) : AppColors.fill,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _resetPassword(AppUser u) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Send a reset link?',
            style: TextStyle(fontSize: 16)),
        content: Text(
          'A password reset link goes to ${u.email}. You will not see the '
          'new password — they set it themselves from the link.',
          style: const TextStyle(
              fontSize: 13, color: AppColors.text2, height: 1.55),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.text2),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Send link'),
          ),
        ],
      ),
    );
    if (go != true) return;

    try {
      await UserAdminService.sendPasswordReset(u);
      if (mounted) _toast('Reset link sent to ${u.email}.');
    } on UserAdminFailure catch (e) {
      if (mounted) _toast(e.message, bad: true);
    }
  }

  Future<void> _toggleActive(AppUser u) async {
    try {
      await UserAdminService.setActive(uid: u.uid, active: !u.active);
      if (!mounted) return;
      _toast(u.active
          ? '${u.displayName} deactivated.'
          : '${u.displayName} restored.');
      _reload();
    } on UserAdminFailure catch (e) {
      if (mounted) _toast(e.message, bad: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BackBar(label: 'Settings', onBack: widget.onBack),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
              child: Text('Evaluators and admins',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3)),
            ),
            FilledButton.icon(
              onPressed: () async {
                final ok = await UserDialog.show(context);
                if (ok == true) {
                  _toast('Account created.');
                  _reload();
                }
              },
              icon: const Icon(Icons.person_add_alt, size: 16),
              label: const Text('New account'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Accounts are created here, not on the phone. Deactivating locks '
          'someone out of both apps immediately.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 18),
        FutureBuilder<List<AppUser>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.greenLight),
                  ),
                ),
              );
            }
            if (snap.hasError) {
              return Panel(
                title: 'Could not load accounts',
                child: Text('${snap.error}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.text2)),
              );
            }
            final users = snap.data ?? const <AppUser>[];
            return Column(
              children: [
                for (var i = 0; i < users.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                        bottom: i == users.length - 1 ? 0 : 10),
                    child: _UserRow(
                      user: users[i],
                      isSelf: users[i].uid == SessionService.user.uid,
                      onEdit: () async {
                        final ok = await UserDialog.show(context,
                            existing: users[i]);
                        if (ok == true) {
                          _toast('Account updated.');
                          _reload();
                        }
                      },
                      onToggleActive: () => _toggleActive(users[i]),
                      onResetPassword: () => _resetPassword(users[i]),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Panel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 17, color: AppColors.muted),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Deactivating locks an account out of both apps, but the '
                  'Firebase login itself can only be removed with server '
                  'credentials. Passwords work the same way: you can send a '
                  'reset link to the person, but you cannot choose a password '
                  'for them. Both are why the email on an account must be '
                  'real and reachable.',
                  style: TextStyle(
                      fontSize: 12.5, color: AppColors.muted, height: 1.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.isSelf,
    required this.onEdit,
    required this.onToggleActive,
    required this.onResetPassword,
  });

  final AppUser user;
  final bool isSelf;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onResetPassword;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 760;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.fill,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            alignment: Alignment.center,
            child: Text(user.initials,
                style: AppTheme.mono(size: 12, color: AppColors.text2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(user.displayName,
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (isSelf) ...[
                      const SizedBox(width: 8),
                      Text('YOU',
                          style: AppTheme.eyebrow
                              .copyWith(color: AppColors.greenLight)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isWide && user.email.isNotEmpty
                      ? '${user.username} · ${user.email}'
                      : user.username,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: user.isAdmin ? AppColors.amberDark : AppColors.fill,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(user.roleLabel,
                style: AppTheme.mono(
                    size: 9.5,
                    color:
                        user.isAdmin ? AppColors.amber : AppColors.muted)),
          ),
          const SizedBox(width: 10),
          if (!user.active)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF3D211C),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('OFF',
                  style: AppTheme.mono(size: 9.5, color: AppColors.orange)),
            ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: onEdit,
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined, size: 16),
            color: AppColors.muted,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: user.email.isEmpty ? null : onResetPassword,
            tooltip: user.email.isEmpty
                ? 'No email on file — cannot send a reset link'
                : 'Send password reset link',
            icon: const Icon(Icons.key_outlined, size: 16),
            color: AppColors.muted,
            disabledColor: const Color(0xFF3A3A3A),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: isSelf ? null : onToggleActive,
            tooltip: isSelf
                ? 'You cannot deactivate yourself'
                : (user.active ? 'Deactivate' : 'Restore'),
            icon: Icon(
                user.active ? Icons.block : Icons.restart_alt,
                size: 16),
            color: user.active ? AppColors.muted : AppColors.greenLight,
            disabledColor: const Color(0xFF3A3A3A),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Farms
// =====================================================================

class _FarmsSection extends StatefulWidget {
  const _FarmsSection({required this.onBack});
  final VoidCallback onBack;

  @override
  State<_FarmsSection> createState() => _FarmsSectionState();
}

class _FarmsSectionState extends State<_FarmsSection> {
  late Future<List<Farm>> _future;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _future = FarmAdminService.listFarms();
  }

  void _reload() => setState(() => _future = FarmAdminService.listFarms());

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BackBar(label: 'Settings', onBack: widget.onBack),
        const SizedBox(height: 16),
        const Text('Farm records',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3)),
        const SizedBox(height: 6),
        const Text(
          'Corrections only. New farms are registered by field officers on '
          'the phone, where the GPS fix is taken.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 300,
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search farm, owner or village',
              prefixIcon:
                  Icon(Icons.search, size: 18, color: AppColors.muted),
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<Farm>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.greenLight),
                  ),
                ),
              );
            }
            if (snap.hasError) {
              return Panel(
                title: 'Could not load farms',
                child: Text('${snap.error}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.text2)),
              );
            }

            final q = _search.trim().toLowerCase();
            final farms = (snap.data ?? const <Farm>[]).where((f) {
              if (q.isEmpty) return true;
              return '${f.name} ${f.ownerManager} ${f.locationArea} '
                      '${f.county}'
                  .toLowerCase()
                  .contains(q);
            }).toList();

            if (farms.isEmpty) {
              return const Panel(
                title: 'No farms match',
                child: Text('Try a different search.',
                    style:
                        TextStyle(fontSize: 13, color: AppColors.text2)),
              );
            }

            return Column(
              children: [
                for (var i = 0; i < farms.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                        bottom: i == farms.length - 1 ? 0 : 10),
                    child: _FarmRow(
                      farm: farms[i],
                      onEdit: () async {
                        final ok =
                            await FarmDialog.show(context, farm: farms[i]);
                        if (ok == true && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Farm updated.'),
                              backgroundColor: AppColors.fill,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          _reload();
                        }
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FarmRow extends StatelessWidget {
  const _FarmRow({required this.farm, required this.onEdit});

  final Farm farm;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(farm.name,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  [farm.ownerManager, farm.locationArea, farm.county]
                      .where((s) => s.isNotEmpty)
                      .join(' · '),
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (farm.contactEmail.isEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Tooltip(
                message: 'No farmer email — reports cannot be sent',
                child: Icon(Icons.mail_outline,
                    size: 15, color: AppColors.amber.withValues(alpha: 0.7)),
              ),
            ),
          Text(farm.systemLabel,
              style: AppTheme.mono(size: 11, color: AppColors.muted)),
          const SizedBox(width: 10),
          IconButton(
            onPressed: onEdit,
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined, size: 16),
            color: AppColors.muted,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Shared bits
// =====================================================================

class _BackBar extends StatelessWidget {
  const _BackBar({required this.label, required this.onBack});

  final String label;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back, size: 16),
        label: Text(label),
        style: TextButton.styleFrom(
            foregroundColor: AppColors.text2, padding: EdgeInsets.zero),
      ),
    );
  }
}

class _BandPreview extends StatelessWidget {
  const _BandPreview({required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    final poor = config.fairMin;
    final fair = (config.goodMin - config.fairMin).clamp(0, 35);
    final good = (config.excellentMin - config.goodMin).clamp(0, 35);
    final excellent = (36 - config.excellentMin).clamp(0, 35);

    Widget seg(int flex, Color c) => flex <= 0
        ? const SizedBox.shrink()
        : Expanded(flex: flex, child: Container(color: c));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                seg(poor, AppColors.scoreRamp[0]),
                seg(fair, AppColors.scoreRamp[2]),
                seg(good, AppColors.scoreRamp[3]),
                seg(excellent, AppColors.scoreRamp[4]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            _Key('Poor', 'below ${config.fairMin}', AppColors.scoreRamp[0]),
            _Key('Fair', '${config.fairMin}–${config.goodMin - 1}',
                AppColors.scoreRamp[2]),
            _Key('Good', '${config.goodMin}–${config.excellentMin - 1}',
                AppColors.scoreRamp[3]),
            _Key('Excellent', '${config.excellentMin}–35',
                AppColors.scoreRamp[4]),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key(this.label, this.range, this.color);

  final String label;
  final String range;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 7),
        Text(label,
            style: const TextStyle(fontSize: 12.5, color: AppColors.text2)),
        const SizedBox(width: 6),
        Text(range, style: AppTheme.mono(size: 11.5, color: AppColors.muted)),
      ],
    );
  }
}

/// Stepper rather than a text field: a threshold is a small integer, and
/// typing invites empty strings and stray letters that all need handling.
class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Container(
            decoration: BoxDecoration(
              color: AppColors.fill,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Step(
                    icon: Icons.remove,
                    enabled: value - step >= min,
                    onTap: () => onChanged(value - step)),
                SizedBox(
                  width: 46,
                  child: Text('$value',
                      textAlign: TextAlign.center,
                      style: AppTheme.mono(size: 14)),
                ),
                _Step(
                    icon: Icons.add,
                    enabled: value + step <= max,
                    onTap: () => onChanged(value + step)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: 16),
      color: AppColors.text2,
      disabledColor: const Color(0xFF3A3A3A),
      hoverColor: AppColors.surface,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry, required this.isLast});

  final DeletionEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isFarm = entry.collection == 'farms';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFF262626))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isFarm ? AppColors.amberDark : AppColors.fill,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(isFarm ? 'FARM' : 'VISIT',
                style: AppTheme.mono(
                    size: 9.5,
                    color: isFarm ? AppColors.amber : AppColors.muted)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.summary.isEmpty ? entry.docId : entry.summary,
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 3),
                Text(
                  [
                    entry.deletedByName,
                    Fmt.relative(entry.deletedAt),
                    if (entry.reason.isNotEmpty) '“${entry.reason}”',
                  ].join(' · '),
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.muted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}