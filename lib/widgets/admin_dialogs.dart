import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/farm.dart';
import '../services/farm_admin_service.dart';
import '../services/user_admin_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Shared form scaffolding for the admin dialogs.
class _FormShell extends StatelessWidget {
  const _FormShell({
    required this.title,
    required this.note,
    required this.children,
    required this.busy,
    required this.error,
    required this.onSave,
    required this.saveLabel,
  });

  final String title;
  final String note;
  final List<Widget> children;
  final bool busy;
  final String? error;
  final VoidCallback onSave;
  final String saveLabel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  Text(note,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                          height: 1.5)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A1512),
                    border: Border.all(color: const Color(0xFF5A2B26)),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 16, color: AppColors.orange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(error!,
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.orange,
                                height: 1.5)),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        busy ? null : () => Navigator.of(context).pop(false),
                    style:
                        TextButton.styleFrom(foregroundColor: AppColors.text2),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: busy ? null : onSave,
                    child: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(saveLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.enabled = true,
    this.help,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final bool enabled;
  final String? help;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.text2)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            obscureText: obscure,
            enabled: enabled,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 13),
            ),
          ),
          if (help != null) ...[
            const SizedBox(height: 5),
            Text(help!,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.muted, height: 1.45)),
          ],
        ],
      ),
    );
  }
}

// =====================================================================
// Create / edit an account
// =====================================================================

class UserDialog extends StatefulWidget {
  const UserDialog({super.key, this.existing});

  /// Null to create, non-null to edit.
  final AppUser? existing;

  static Future<bool?> show(BuildContext context, {AppUser? existing}) =>
      showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => UserDialog(existing: existing),
      );

  @override
  State<UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<UserDialog> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  bool _isAdmin = false;
  bool _busy = false;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final u = widget.existing;
    if (u != null) {
      _name.text = u.fullName;
      _username.text = u.username;
      _email.text = u.email;
      _phone.text = u.phone;
      _isAdmin = u.isAdmin;
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _username, _email, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_editing) {
        await UserAdminService.updateProfile(
          uid: widget.existing!.uid,
          fullName: _name.text,
          phone: _phone.text,
        );
        if (_isAdmin != widget.existing!.isAdmin) {
          await UserAdminService.setRole(
              uid: widget.existing!.uid, isAdmin: _isAdmin);
        }
      } else {
        await UserAdminService.createUser(
          fullName: _name.text,
          username: _username.text,
          email: _email.text,
          phone: _phone.text,
          password: _password.text,
          isAdmin: _isAdmin,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on UserAdminFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FormShell(
      title: _editing ? 'Edit account' : 'New account',
      note: _editing
          ? 'Username and email are the login credentials and cannot be '
              'changed here.'
          : 'The person signs in with the username and password you set. '
              'Give them the password directly — nothing is emailed.',
      busy: _busy,
      error: _error,
      saveLabel: _editing ? 'Save' : 'Create account',
      onSave: _save,
      children: [
        _Field(label: 'Full name', controller: _name, hint: 'e.g. P. Kiptoo'),
        _Field(
          label: 'Username',
          controller: _username,
          hint: 'e.g. p.kiptoo',
          enabled: !_editing,
          help: _editing
              ? null
              : 'Lowercase, no spaces. This is what they type to sign in.',
        ),
        _Field(
          label: 'Email',
          controller: _email,
          hint: 'name@company.co.ke',
          enabled: !_editing,
          help: _editing
              ? null
              : 'Firebase signs people in by email behind the scenes. It '
                  'must be unique and real enough to receive a password '
                  'reset.',
        ),
        _Field(label: 'Phone', controller: _phone, hint: 'Optional'),
        if (!_editing)
          _Field(
            label: 'Temporary password',
            controller: _password,
            obscure: true,
            help: 'At least 6 characters. They can change it later from a '
                'password reset email.',
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.fill,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Administrator',
                        style: TextStyle(fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(
                      _isAdmin
                          ? 'Can edit and delete anything, and manage accounts'
                          : 'Can view everything and pull exports',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isAdmin,
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _isAdmin = v),
                activeThumbColor: AppColors.amber,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

// =====================================================================
// Edit a farm
// =====================================================================

class FarmDialog extends StatefulWidget {
  const FarmDialog({super.key, required this.farm});

  final Farm farm;

  static Future<bool?> show(BuildContext context, {required Farm farm}) =>
      showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => FarmDialog(farm: farm),
      );

  @override
  State<FarmDialog> createState() => _FarmDialogState();
}

class _FarmDialogState extends State<FarmDialog> {
  late final TextEditingController _name;
  late final TextEditingController _owner;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _county;
  late final TextEditingController _subCounty;
  late final TextEditingController _village;

  late String _system;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final f = widget.farm;
    _name = TextEditingController(text: f.name);
    _owner = TextEditingController(text: f.ownerManager);
    _phone = TextEditingController(text: f.contactPhone);
    _email = TextEditingController(text: f.contactEmail);
    _county = TextEditingController(text: f.county);
    _subCounty = TextEditingController(text: f.subCounty);
    _village = TextEditingController(text: f.locationArea);
    _system = FarmAdminService.productionSystems.contains(f.productionSystem)
        ? f.productionSystem
        : FarmAdminService.productionSystems.first;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _owner,
      _phone,
      _email,
      _county,
      _subCounty,
      _village
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FarmAdminService.update(
        farm: widget.farm,
        name: _name.text,
        ownerManager: _owner.text,
        contactPhone: _phone.text,
        contactEmail: _email.text,
        county: _county.text,
        subCounty: _subCounty.text,
        locationArea: _village.text,
        productionSystem: _system,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on FarmAdminFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FormShell(
      title: 'Edit farm',
      note: 'Registered by ${widget.farm.createdByName}. Who registered a '
          'farm never changes, even on an admin edit.',
      busy: _busy,
      error: _error,
      saveLabel: 'Save changes',
      onSave: _save,
      children: [
        _Field(label: 'Farm name', controller: _name),
        _Field(label: 'Owner / manager', controller: _owner),
        _Field(label: 'Contact phone', controller: _phone),
        _Field(
          label: 'Farmer email',
          controller: _email,
          hint: 'Optional',
          help: 'Used when the visit report is emailed to the farmer.',
        ),
        _Field(label: 'County', controller: _county),
        _Field(label: 'Sub-county', controller: _subCounty),
        _Field(
          label: 'Village',
          controller: _village,
          help: 'Required — the mobile app treats this as mandatory too.',
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Production system',
                  style: TextStyle(fontSize: 12, color: AppColors.text2)),
              const SizedBox(height: 6),
              Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.fill,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _system,
                    isExpanded: true,
                    items: FarmAdminService.productionSystems
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(Fmt.humanise(s),
                                  style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _system = v ?? _system),
                    dropdownColor: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    icon: const Icon(Icons.expand_more,
                        size: 18, color: AppColors.muted),
                  ),
                ),
              ),
            ],
          ),
        ),
        Text(
          'Farm ID ${widget.farm.id}',
          style: AppTheme.mono(size: 10.5, color: AppColors.muted),
        ),
      ],
    );
  }
}